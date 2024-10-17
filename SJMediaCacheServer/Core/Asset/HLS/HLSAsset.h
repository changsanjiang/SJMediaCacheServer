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
@property (nonatomic, strong, nullable) HLSAssetParser *parser; 

- (NSString *)indexFilepath;
- (NSString *)indexFileRelativePath;
- (NSString *)AESKeyFilepathWithURL:(NSURL *)URL;
- (nullable NSArray<id<HLSAssetTsContent>> *)TsContents;
- (nullable id<HLSAssetTsContent>)TsContentReadwriteForRequest:(NSURLRequest *)request;


- (nullable id<MCSAssetContent>)createContentReadwriteWithDataType:(MCSDataType)dataType response:(id<MCSDownloadResponse>)response;
- (void)enumerateContentNodesUsingBlock:(void(NS_NOESCAPE ^)(MCSAssetContentNode *node, BOOL *stop))block;
@end


// 需要有index文件后才能继续操作node
// 那index文件就有了默认的placement

//@interface <#class name#> : <#superclass#>
//
//@end
NS_ASSUME_NONNULL_END
