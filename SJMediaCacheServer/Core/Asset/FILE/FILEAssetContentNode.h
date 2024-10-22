//
//  FILEAssetContentNode.h
//  SJMediaCacheServer
//
//  Created by db on 2024/10/16.
//

#import "MCSAssetDefines.h"

NS_ASSUME_NONNULL_BEGIN
@interface FILEAssetContentNode : NSObject
@property (nonatomic, unsafe_unretained, readonly, nullable) FILEAssetContentNode *prev;
@property (nonatomic, unsafe_unretained, readonly, nullable) FILEAssetContentNode *next;
@property (nonatomic, readonly) UInt64 placement;
@property (nonatomic, readonly, nullable) id<MCSAssetContent> longestContent;
@property (nonatomic, readonly, nullable) id<MCSAssetContent> idleContent; // 当前未读写并且长度最长的content
@property (nonatomic, readonly, nullable) NSArray<id<MCSAssetContent>> *contents;
@property (nonatomic, readonly) NSUInteger numberOfContents;
- (void)trimExcessContentsWithTest:(BOOL (NS_NOESCAPE ^)(id<MCSAssetContent> content, BOOL *stop))predicate; // 清理多余无用的 content;
- (void)removeContent:(id<MCSAssetContent>)content;
@end

@interface FILEAssetContentNodeList : NSObject
@property (nonatomic, readonly) NSUInteger count; // nodes count
@property (nonatomic, readonly, nullable) FILEAssetContentNode *head;
@property (nonatomic, readonly, nullable) FILEAssetContentNode *tail;
- (void)attachContentToNode:(id<MCSAssetContent>)content placement:(UInt64)placement;
- (void)removeNode:(FILEAssetContentNode *)node;
- (void)removeAllNodes;
- (void)enumerateNodesUsingBlock:(void(NS_NOESCAPE ^)(FILEAssetContentNode *node, BOOL *stop))block;
@end
NS_ASSUME_NONNULL_END
