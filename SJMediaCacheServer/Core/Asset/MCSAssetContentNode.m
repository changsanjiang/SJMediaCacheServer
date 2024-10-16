//
//  MCSAssetContentNode.m
//  SJMediaCacheServer
//
//  Created by db on 2024/10/16.
//

#import "MCSAssetContentNode.h"

@interface MCSAssetContentNode ()
- (instancetype)initWithContent:(id<MCSAssetContent>)content;
@property (nonatomic, unsafe_unretained, nullable) MCSAssetContentNode *prev;
@property (nonatomic, unsafe_unretained, nullable) MCSAssetContentNode *next;
- (void)addContent:(id<MCSAssetContent>)content;
- (void)removeContentAtIndex:(NSInteger)index;
@end

@implementation MCSAssetContentNode {
    NSMutableArray<id<MCSAssetContent>> *mContents;
}

- (instancetype)initWithContent:(id<MCSAssetContent>)content {
    self = [super init];
    mContents = [NSMutableArray arrayWithObject:content];
    return self;
}

- (UInt64)startPositionInAsset {
    return mContents.firstObject.startPositionInAsset;
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
    return [NSString stringWithFormat:@"%@: <%p> { startPositionInAsset: %llu, maximumLength: %llu, contents: %lu };\n", NSStringFromClass(self.class), self, self.startPositionInAsset, self.longestContent.length, (unsigned long)mContents.count];
}
@end


@implementation MCSAssetContentNodeList {
    NSMutableDictionary<NSNumber *, MCSAssetContentNode *> *mNodes;
}

- (instancetype)initWithContents:(nullable NSArray<id<MCSAssetContent>> *)contents {
    self = [super init];
    mNodes = NSMutableDictionary.dictionary;
    for ( id<MCSAssetContent> content in contents ) {
        [self attachContentToNode:content];
    }
    return self;
}

- (NSUInteger)count {
    return mNodes.count;
}

/// 将内容 content 附加到某个节点, 如果该节点不存在, 则创建一个新节点并将其插入到链表中;
- (void)attachContentToNode:(id<MCSAssetContent>)content {
    UInt64 curNodePosition = content.startPositionInAsset;
    NSNumber *curNodeKey = @(curNodePosition);
    MCSAssetContentNode *curNode = mNodes[curNodeKey];
    if ( curNode == nil ) {
        // create new node
        //
        curNode = [MCSAssetContentNode.alloc initWithContent:content];
        mNodes[curNodeKey] = curNode;
         
        // position is startPositionInAsset
        //
        // restructure nodes position
        //
        // prevNode.position < curNode.position < nextNode.position
        //
        // preNode.next = curNode; curNode.prev = prevNode, curNode.next = nextNode; nextNode.prev = curNode;
        //
        MCSAssetContentNode *prevNode = _tail;
        MCSAssetContentNode *nextNode = nil;
        while ( prevNode.startPositionInAsset > curNodePosition ) {
            nextNode = prevNode;
            prevNode = prevNode.prev;
        }
        
        prevNode.next = curNode;
        curNode.prev = prevNode;
        curNode.next = nextNode;
        nextNode.prev = curNode;
        
        if ( _head == nil || _head.startPositionInAsset > curNodePosition ) {
            _head = curNode;
        }
        
        if ( _tail == nil || _tail.startPositionInAsset < curNodePosition ) {
            _tail = curNode;
        }
    }
    else {
        [curNode addContent:content];
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
    
    NSNumber *nodeKey = @(node.startPositionInAsset);
    [mNodes removeObjectForKey:nodeKey];
}
@end
