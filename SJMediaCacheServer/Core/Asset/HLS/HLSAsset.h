//
//  HLSAsset.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSInterfaces.h"
#import "HLSAssetParser.h"
#import "HLSAssetDefines.h"
#import "MCSReadwrite.h"
#import "MCSAssetContentNode.h"

NS_ASSUME_NONNULL_BEGIN
@interface HLSAsset : MCSReadwrite<MCSAsset>
@property (nonatomic, readonly) MCSAssetType type;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, strong, readonly) id<MCSConfiguration> configuration;
@property (nonatomic, readonly) NSUInteger tsCount;
@property (nonatomic, readonly) BOOL isStored;
@property (nonatomic, strong, readonly, nullable) HLSAssetParser *parser; 

- (NSString *)playlistFilePath;
- (NSString *)getPlaylistRelativePath;
- (NSString *)AESKeyFilePathWithURL:(NSURL *)URL;
- (nullable NSArray<id<HLSAssetTsContent>> *)TsContents;
- (nullable id<HLSAssetTsContent>)TsContentReadwriteForRequest:(NSURLRequest *)request;


- (nullable id<MCSAssetContent>)createContentReadwriteWithDataType:(MCSDataType)dataType response:(id<MCSDownloadResponse>)response;
- (void)enumerateContentNodesUsingBlock:(void(NS_NOESCAPE ^)(MCSAssetContentNode *node, BOOL *stop))block;




- (nullable id<MCSAssetReader>)readerWithRequest:(id<MCSRequest>)request networkTaskPriority:(float)networkTaskPriority readDataDecoder:(NSData *(^_Nullable)(NSURLRequest *request, NSUInteger offset, NSData *data))readDataDecoder delegate:(nullable id<MCSAssetReaderDelegate>)delegate;

- (nullable id<MCSAssetContent>)getPlaylistContent; // retained, should release after;
- (nullable id<MCSAssetContent>)createPlaylistContent:(NSString *)proxyPlaylist error:(out NSError **)error; // retained, should release after;

- (nullable id<MCSAssetContent>)getAESKeyContentWithOriginalURL:(NSURL *)originalURL; // retained, should release after;
- (nullable id<MCSAssetContent>)createAESKeyContentWithOriginalURL:(NSURL *)originalURL data:(NSData *)data error:(out NSError **)error; // retained, should release after;
@end
NS_ASSUME_NONNULL_END
