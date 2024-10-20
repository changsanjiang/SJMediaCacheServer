//
//  HLSAssetSegmentNode.h
//  SJMediaCacheServer
//
//  Created by db on 2024/10/18.
//

#import "HLSAssetDefines.h"

NS_ASSUME_NONNULL_BEGIN
@interface HLSAssetSegmentNode : NSObject
@property (nonatomic, strong, readonly) NSString *identifier;
@property (nonatomic, readonly, nullable) id<HLSAssetSegment> fullContent; // 内容已填充完毕的content
@property (nonatomic, readonly, nullable) id<HLSAssetSegment> idleContent; // 当前未读写并且长度最长的content
@property (nonatomic, readonly, nullable) id<HLSAssetSegment> fullOrIdleContent;
@property (nonatomic, readonly) NSUInteger numberOfContents;
- (void)trimExcessContentsWithTest:(BOOL (NS_NOESCAPE ^)(id<HLSAssetSegment> content, BOOL *stop))predicate; // 清理多余无用的 content;
@end


@interface HLSAssetSegmentNodeMap : NSObject
@property (nonatomic, readonly) NSUInteger count; // nodes 
- (nullable HLSAssetSegmentNode *)nodeForIdentifier:(NSString *)identifier;
- (void)attachContentToNode:(id<HLSAssetSegment>)content identifier:(NSString *)identifier;
- (void)enumerateNodesUsingBlock:(void(NS_NOESCAPE ^)(HLSAssetSegmentNode *node, BOOL *stop))block;
- (void)removeAllNodes;
@end
NS_ASSUME_NONNULL_END
