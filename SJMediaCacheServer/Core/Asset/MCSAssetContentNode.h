//
//  MCSAssetContentNode.h
//  SJMediaCacheServer
//
//  Created by db on 2024/10/16.
//

#import "MCSAssetDefines.h"

NS_ASSUME_NONNULL_BEGIN
@interface MCSAssetContentNode : NSObject
@property (nonatomic, unsafe_unretained, readonly, nullable) MCSAssetContentNode *prev;
@property (nonatomic, unsafe_unretained, readonly, nullable) MCSAssetContentNode *next;
@property (nonatomic, readonly) UInt64 placement;
@property (nonatomic, readonly, nullable) id<MCSAssetContent> longestContent;
@property (nonatomic, readonly) NSInteger numberOfContents;
- (void)trimExcessContentsWithTest:(BOOL (NS_NOESCAPE ^)(id<MCSAssetContent> content, BOOL *stop))predicate; // 清理多余无用的 content;
@end

@interface MCSAssetContentNodeList : NSObject
@property (nonatomic, readonly) NSUInteger count; // nodes count
@property (nonatomic, readonly, nullable) MCSAssetContentNode *head;
@property (nonatomic, readonly, nullable) MCSAssetContentNode *tail;
- (void)attachContentToNode:(id<MCSAssetContent>)content placement:(UInt64)placement;
- (void)removeNode:(MCSAssetContentNode *)node;
- (void)enumerateNodesUsingBlock:(void(NS_NOESCAPE ^)(MCSAssetContentNode *node, BOOL *stop))block;
@end
NS_ASSUME_NONNULL_END
