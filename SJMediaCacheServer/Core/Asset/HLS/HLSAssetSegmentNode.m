//
//  HLSAssetSegmentNode.m
//  SJMediaCacheServer
//
//  Created by db on 2024/10/18.
//

#import "HLSAssetSegmentNode.h"

@interface HLSAssetSegmentNode ()
- (instancetype)initWithContent:(id<HLSAssetSegment>)content identifier:(NSString *)identifier;
- (void)addContent:(id<HLSAssetSegment>)content;
- (void)removeContentAtIndex:(NSInteger)index;
@end

@implementation HLSAssetSegmentNode {
    NSString *mIdentifier;
    NSMutableArray<id<HLSAssetSegment>> *mContents;
}

- (instancetype)initWithContent:(id<HLSAssetSegment>)content identifier:(NSString *)identifier {
    self = [super init];
    mIdentifier = identifier;
    mContents = [NSMutableArray arrayWithObject:content];
    return self;
}

- (NSString *)identifier {
    return mIdentifier;
}

- (nullable id<HLSAssetSegment>)fullContent {
    id<HLSAssetSegment> retv = nil;
    for ( NSInteger i = 0 ; i < mContents.count ; ++ i ) {
        id<HLSAssetSegment> content = mContents[i];
        if ( content.length == content.byteRange.length ) {
            retv = content;
            break;
        }
    }
    return retv;
}

- (nullable id<HLSAssetSegment>)idleContent {
    id<HLSAssetSegment> retv = nil;
    for ( NSInteger i = 0 ; i < mContents.count ; ++ i ) {
        id<HLSAssetSegment> content = mContents[i];
        UInt64 length = content.length;
        if ( content.readwriteCount == 0 && (retv == nil || content.length > retv.length) ) {
            retv = content;
        }
    }
    return retv;
}

- (nullable id<HLSAssetSegment>)fullOrIdleContent {
    return self.fullContent ?: self.idleContent;
}

- (void)trimExcessContentsWithTest:(BOOL (NS_NOESCAPE ^)(id<HLSAssetSegment> content, BOOL *stop))predicate {
    [mContents enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id<HLSAssetSegment>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        BOOL shouldRemove = predicate(obj, stop);
        if ( shouldRemove ) {
            [self removeContentAtIndex:idx];
        }
    }];
}

- (NSUInteger)numberOfContents {
    return mContents.count;
}

- (void)addContent:(id<HLSAssetSegment>)content {
    [mContents addObject:content];
}

- (void)removeContentAtIndex:(NSInteger)index {
    [mContents removeObjectAtIndex:index];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@: <%p> { identifier: %@, fullContent: %@, idleContent: %@, contents: %lu };\n", NSStringFromClass(self.class), self, self.identifier, self.fullContent, self.idleContent, (unsigned long)mContents.count];
}
@end

@implementation HLSAssetSegmentNodeMap {
    NSMutableDictionary<NSString *, HLSAssetSegmentNode *> *mNodes;
}

- (instancetype)init {
    self = [super init];
    mNodes = NSMutableDictionary.dictionary;
    return self;
}

- (NSUInteger)count {
    return mNodes.count;
}

- (nullable HLSAssetSegmentNode *)nodeForIdentifier:(NSString *)identifier {
    return mNodes[identifier];
}

- (void)attachContentToNode:(id<HLSAssetSegment>)content identifier:(NSString *)identifier {
    HLSAssetSegmentNode *node = mNodes[identifier];
    if ( node != nil ) {
        [node addContent:content];
    }
    else {
        node = [HLSAssetSegmentNode.alloc initWithContent:content identifier:identifier];
        mNodes[identifier] = node;
    }
}

- (void)enumerateNodesUsingBlock:(void(NS_NOESCAPE ^)(HLSAssetSegmentNode *node, BOOL *stop))block {
    [mNodes enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, HLSAssetSegmentNode * _Nonnull obj, BOOL * _Nonnull stop) {
        block(obj, stop);
    }];
}

- (void)removeAllNodes {
    [mNodes removeAllObjects];
}
@end
