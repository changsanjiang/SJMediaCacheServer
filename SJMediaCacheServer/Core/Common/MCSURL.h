//
//  MCSURL.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSInterfaces.h"
#import "NSURL+MCS.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSURL : NSObject
+ (instancetype)shared;

@property (nonatomic, strong, nullable) NSURL *serverURL;

@property (nonatomic, copy, nullable) MCSAssetType (^resolveAssetType)(NSURL *URL);
@property (nonatomic, copy, nullable) NSString *(^resolveAssetIdentifier)(NSURL *URL);

- (NSURL *)generateProxyURLFromURL:(NSURL *)URL; // 生成代理URL
- (NSURL *)restoreURLFromProxyURL:(NSURL *)proxyURL; // 还原URL

- (NSString *)getAssetNameBy:(NSURL *)URL; // URL: `proxyURL or originalURL`
- (MCSAssetType)getAssetTypeBy:(NSURL *)URL; // URL: `proxyURL or originalURL`





#pragma mark - hls

- (MCSDataType)dataTypeForProxyURL:(NSURL *)proxyURL;
- (NSString *)nameWithUrl:(NSString *)url suffix:(NSString *)suffix;
- (NSURL *)proxyURLWithRelativePath:(NSString *)path inAsset:(NSString *)assetName;
- (NSString *)proxyFilenameWithOriginalURL:(NSURL *)originalURL dataType:(MCSDataType)dataType;
@end


@interface MCSURL (HLS)
- (NSString *)HLS_proxyURIWithURL:(NSString *)url suffix:(NSString *)suffix inAsset:(NSString *)asset;
- (NSURL *)HLS_URLWithProxyURI:(NSString *)proxyURI;
- (NSURL *)HLS_proxyURLWithProxyURI:(NSString *)uri;
@end
NS_ASSUME_NONNULL_END
