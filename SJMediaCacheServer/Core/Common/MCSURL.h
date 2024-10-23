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

/// A block that resolves the asset type for a given URL.
/// The asset type (e.g., HLS or file) can be determined based on the URL.
/// Can return a custom MCSAssetType or fallback to default behavior if not set.
@property (nonatomic, copy, nullable) MCSAssetType (^resolveAssetType)(NSURL *URL);

/// A block that resolves the asset identifier for a given URL.
/// This can be used to generate a unique identifier for the URL, such as an MD5 hash.
/// If not set, the default behavior for resolving asset identifiers should be used.
@property (nonatomic, copy, nullable) NSString *(^resolveAssetIdentifier)(NSURL *URL);

/// Generates a proxy URL from an original URL.
///
/// If the original URL already contains PROXY_FLAG, it returns the original URL.
/// Otherwise, it generates a new proxy URL.
///
/// @param URL The original URL.
/// @return The generated proxy URL.
- (NSURL *)generateProxyURLFromURL:(NSURL *)URL; // 生成代理URL

/// Restores the original URL from a proxy URL.
///
/// If the proxy URL belongs to the server, it decodes the base64-encoded original URL from the query.
/// If it is not a proxy URL, it returns the URL as-is.
///
/// @param proxyURL The proxy URL.
/// @return The restored original URL.
- (NSURL *)restoreURLFromProxyURL:(NSURL *)proxyURL; // 还原URL

/// Retrieves the asset name based on the provided URL.
/// If the URL contains HLS_PROXY_URI_FLAG, it is considered an internal HLS resource request, and the asset name is extracted.
/// Otherwise, the original URL is restored and the asset name is determined based on its MD5 hash.
///
/// @param URL The URL for which to retrieve the asset name.
/// @return The asset name, either derived from the proxy path or the MD5 of the original URL.
- (NSString *)assetNameForURL:(NSURL *)URL; // URL: `proxyURL or originalURL`

/// Determines the asset type based on the provided URL.
/// If the resolveAssetType block is provided, it is used to determine the type.
/// Otherwise, it checks the URL's path for HLS-specific extensions (playlist, segment, AES key).
///
/// @param URL The URL for which to determine the asset type.
/// @return The asset type (e.g., HLS or file).
- (MCSAssetType)assetTypeForURL:(NSURL *)URL; // URL: `proxyURL or originalURL`

@end


@interface MCSURL (HLS)
/// Determines the data type based on the provided HLS proxy URL.
///
/// @param proxyURL The HLS proxy URL.
/// @return The data type (e.g., HLS playlist, AES key, or segment).
- (MCSDataType)dataTypeForHLSProxyURL:(NSURL *)proxyURL;

/// Generates a proxy URI for an HLS original URL.
///
/// The proxyURI format is: mcsproxy/assetName/proxyIdentifier(urlmd5.extension)?url=base64EncodedUrl(originalUrl)
/// - mcsproxy: The base proxy path.
/// - assetName: The name of the asset.
/// - proxyIdentifier: The identifier generated from the original URL's MD5 and its extension.
/// - base64EncodedUrl: The base64-encoded original URL.
///
/// @param url The original HLS URL.
/// @param extension The file extension to be used (e.g., .m3u8, .ts).
/// @param assetName The asset name associated with the URL.
/// @return The generated proxy URI.
- (NSString *)generateProxyURIFromHLSOriginalURL:(NSURL *)url extension:(NSString *)extension forAsset:(NSString *)assetName;

/// Generates a unique proxy identifier from the original HLS URL.
///
/// The proxyIdentifier format is: urlmd5.extension
/// - urlmd5: The MD5 hash of the original URL to ensure uniqueness.
/// - extension: The file extension (e.g., .m3u8, .ts) to identify the file type.
///
/// @param url The original HLS URL.
/// @param extension The file extension to be used in the identifier.
/// @return The generated proxy identifier.
- (NSString *)generateProxyIdentifierFromHLSOriginalURL:(NSURL *)url extension:(nullable NSString *)extension;
- (NSString *)generateProxyIdentifierFromHLSOriginalURL:(NSURL *)url extension:(nullable NSString *)extension byteRange:(NSRange)byteRange;
- (NSString *)generateProxyIdentifierFromHLSOriginalURL:(NSURL *)url;

/// Generates a full proxy URL based on the provided proxy URI.
///
/// @param proxyURI The proxy URI.
/// @return The generated proxy URL.
- (NSURL *)generateProxyURLFromHLSProxyURI:(NSString *)proxyURI;

/// Restores the original URL from an HLS proxy URI.
///
/// @param proxyURI The proxy URI.
/// @return The restored original URL.
- (NSURL *)restoreURLFromHLSProxyURI:(NSString *)proxyURI;
@end
NS_ASSUME_NONNULL_END
