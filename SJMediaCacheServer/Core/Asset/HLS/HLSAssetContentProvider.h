//
//  HLSAssetContentProvider.h
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/11/25.
//
 
#import "HLSAssetDefines.h"
@class HLSAssetParser;

NS_ASSUME_NONNULL_BEGIN

@interface HLSAssetContentProvider : NSObject
- (instancetype)initWithDirectory:(NSString *)directory;

- (NSString *)getPlaylistFilePath;
- (NSString *)getPlaylistRelativePath;

- (NSString *)getAESKeyFilePath:(NSString *)filename;






- (nullable NSArray<id<HLSAssetTsContent>> *)loadTsContentsWithParser:(HLSAssetParser *)parser;
- (nullable id<HLSAssetTsContent>)createTsContentWithName:(NSString *)name totalLength:(NSUInteger)totalLength;
- (nullable id<HLSAssetTsContent>)createTsContentWithName:(NSString *)name totalLength:(NSUInteger)totalLength rangeInAsset:(NSRange)range;
- (nullable NSString *)TsContentFilePath:(id<HLSAssetTsContent>)content;
- (void)removeTsContent:(id<HLSAssetTsContent>)content;


//content = [mProvider createContentAtOffset:offset pathExtension:_pathExtension];
//[content readwriteRetain];
//if ( content != nil ) [mNodeList attachContentToNode:content placement:content.startPositionInAsset];
- (nullable id<MCSAssetContent>)createContentWithType:(MCSDataType)dataType pathExtension:(nullable NSString *)pathExtension;
@end
NS_ASSUME_NONNULL_END
