//
//  MCSAssetContentNode.m
//  SJMediaCacheServer
//
//  Created by db on 2024/10/16.
//

#import "MCSAssetContentNode.h"

@interface MCSAssetContentNode ()
- (instancetype)initWithContent:(id<MCSAssetContent>)content placement:(UInt64)placement;
@property (nonatomic, unsafe_unretained, nullable) MCSAssetContentNode *prev;
@property (nonatomic, unsafe_unretained, nullable) MCSAssetContentNode *next;
- (void)addContent:(id<MCSAssetContent>)content;
- (void)removeContentAtIndex:(NSInteger)index;
@end

@implementation MCSAssetContentNode {
    UInt64 mPlacement;
    NSMutableArray<id<MCSAssetContent>> *mContents;
}

- (instancetype)initWithContent:(id<MCSAssetContent>)content placement:(UInt64)placement {
    self = [super init];
    mPlacement = placement;
    mContents = [NSMutableArray arrayWithObject:content];
    return self;
}

- (UInt64)placement {
    return mPlacement;
}

- (nullable id<MCSAssetContent>)longestContent {
    id<MCSAssetContent> retv = mContents.firstObject;
    for ( NSInteger i = 1 ; i < mContents.count ; ++ i ) {
        id<MCSAssetContent> content = mContents[i];
        if ( content.length > retv.length ) {
            retv = content;
        }
    }
    return retv;
}

- (void)trimExcessContentsWithTest:(BOOL (NS_NOESCAPE ^)(id<MCSAssetContent> content, BOOL *stop))predicate {
    [mContents enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id<MCSAssetContent>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        BOOL shouldRemove = predicate(obj, stop);
        if ( shouldRemove ) {
            [self removeContentAtIndex:idx];
        }
    }];
}

- (NSInteger)numberOfContents {
    return mContents.count;
}

- (void)addContent:(id<MCSAssetContent>)content {
    [mContents addObject:content];
}

- (void)removeContentAtIndex:(NSInteger)index {
    [mContents removeObjectAtIndex:index];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@: <%p> { placement: %llu, maximumLength: %llu, contents: %lu };\n", NSStringFromClass(self.class), self, mPlacement, self.longestContent.length, (unsigned long)mContents.count];
}
@end


@implementation MCSAssetContentNodeList {
    NSMutableDictionary<NSNumber *, MCSAssetContentNode *> *mNodes;
}

- (NSUInteger)count {
    return mNodes.count;
}

/// 将内容 content 附加到某个节点, 如果该节点不存在, 则创建一个新节点并将其插入到链表中;
- (void)attachContentToNode:(id<MCSAssetContent>)content placement:(UInt64)placement {
    NSNumber *curNodeKey = @(placement);
    MCSAssetContentNode *curNode = mNodes[curNodeKey];
    if ( curNode != nil ) {
        [curNode addContent:content];
        return;
    }
    
    // create new node
    //
    curNode = [MCSAssetContentNode.alloc initWithContent:content placement:placement];
    mNodes[curNodeKey] = curNode;
    
    if ( _head == nil ) {
        _head = curNode;
        _tail = curNode;
        return;
    }
    
    // Restructure nodes in the linked list to insert the new node;
    //
    // Ensure that prevNode.placement < curNode.placement < nextNode.placement;
    //
    // preNode.next = curNode; curNode.prev = prevNode, curNode.next = nextNode; nextNode.prev = curNode;
    
    // 如果新节点位置比头节点小直接插入头部
    if ( placement < _head.placement ) {
        curNode.next = _head;
        _head.prev = curNode;
        _head = curNode;
        return;
    }
    
    // 如果新节点位置比尾节点大直接插入尾部
    if ( placement > _tail.placement ) {
        curNode.prev = _tail;
        _tail.next = curNode;
        _tail = curNode;
        return;
    }
    
    // 寻找合适的前后节点
    MCSAssetContentNode *prevNode = _tail;
    MCSAssetContentNode *nextNode = nil;

    while ( prevNode != nil && prevNode.placement > placement ) {
        nextNode = prevNode;
        prevNode = prevNode.prev;
    }
    
    // 插入节点到链表
    if ( prevNode != nil ) {
        prevNode.next = curNode;
        curNode.prev = prevNode;
    }
    
    if ( nextNode != nil ) {
        curNode.next = nextNode;
        nextNode.prev = curNode;
    }
}

- (void)enumerateNodesUsingBlock:(void(NS_NOESCAPE ^)(MCSAssetContentNode *node, BOOL *stop))block {
    BOOL stop = NO;
    MCSAssetContentNode *cur = _head;
    while ( cur != nil ) {
        block(cur, &stop);
        cur = cur.next;
        if ( stop ) break;;
    }
}

- (void)removeNode:(MCSAssetContentNode *)node {
    MCSAssetContentNode *prevNode = node.prev;
    MCSAssetContentNode *nextNode = node.next;
    nextNode.prev = prevNode;
    prevNode.next = nextNode;

    if ( _head == node ) _head = nextNode;
    if ( _tail == node ) _tail = prevNode;
    
    NSNumber *nodeKey = @(node.placement);
    [mNodes removeObjectForKey:nodeKey];
}
@end
