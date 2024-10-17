//
//  MCSURL.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSURL.h"
#import "MCSConsts.h"
#include <CommonCrypto/CommonCrypto.h>

static NSString * const MCS_PROXY_FLAG = @"mcsproxy";

static inline NSString *
MCSMD5(NSString *str) {
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, (CC_LONG)data.length, result);
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]];
}

@implementation NSString (MCSFileManagerExtended)
- (NSString *)mcs_fname {
    return MCSMD5(self);
}
@end

@implementation NSURL (MCSFileManagerExtended)
- (NSString *)mcs_fname {
    return self.absoluteString.mcs_fname;
}
- (NSString *)mcs_extension {
    return self.path.pathExtension;
}
@end


@implementation MCSURL
+ (instancetype)shared {
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (NSURL *)generateProxyURLFromURL:(NSURL *)originalURL {
    NSAssert(_serverURL != nil, @"The serverURL can't be nil!");
    
    // If the URL is already a proxy URL or matches the server host, return it as-is.
    // Format: mcsproxy/assetName/proxyFilename(urlmd5.extension)?url=base64EncodedUrl(originalUrl)
    if ( [originalURL.path containsString:MCS_PROXY_FLAG] || [originalURL.host isEqualToString:_serverURL.host] ) {
        return originalURL;
    }

    // Create proxy URL with encoded original URL as a query parameter.
    NSURLComponents *components = [NSURLComponents componentsWithURL:_serverURL resolvingAgainstBaseURL:NO];
    components.path = [@"/mcsproxy" stringByAppendingPathComponent:originalURL.path];
    components.query = [NSString stringWithFormat:@"url=%@", [self encode:originalURL.absoluteString]];
    return components.URL;
}

- (NSURL *)restoreURLFromProxyURL:(NSURL *)proxyURL {
    NSAssert(_serverURL != nil, @"The serverURL can't be nil!");

    if ( [proxyURL.host isEqualToString:_serverURL.host] ) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:proxyURL resolvingAgainstBaseURL:NO];
        for ( NSURLQueryItem *queryItem in components.queryItems ) {
            if ( [queryItem.name isEqualToString:@"url"] ) {
                NSString *decodedURLString = [self decode:queryItem.value];
                return [NSURL URLWithString:decodedURLString];
            }
        }
    }
    // Return as-is if it's not a proxy URL.
    return proxyURL;
}

- (NSString *)assetNameForURL:(NSURL *)URL {
    NSAssert(_serverURL != nil, @"The serverURL can't be nil!");
    NSParameterAssert(URL.host);
    
    if ( [URL.path containsString:MCS_PROXY_FLAG] ) {
        // If the URL contains "mcsproxy", return the asset name from the path.
        // Format: mcsproxy/assetName/proxyFilename(urlmd5.extension)?url=base64EncodedUrl(originalUrl)
        return URL.path.stringByDeletingLastPathComponent.lastPathComponent;
    }
    
    // Otherwise, restore the original URL from the proxy URL.
    NSURL *originalURL = [self restoreURLFromProxyURL:URL];
    // Use the resolveAssetIdentifier block, if available, to generate the asset identifier.
    NSString *assetIdentifier = self.resolveAssetIdentifier != nil ? self.resolveAssetIdentifier(originalURL) : originalURL.absoluteString;
    NSParameterAssert(assetIdentifier);  // Ensure the identifier is not nil.
    
    // The asset name is the MD5 hash of the asset identifier.
    NSString *assetName = MCSMD5(assetIdentifier);
    return assetName;
}

- (MCSAssetType)assetTypeForURL:(NSURL *)URL {
    NSURL *originalURL = [self restoreURLFromProxyURL:URL];
    
    // Use the resolveAssetType block if it exists.
    if ( _resolveAssetType != nil ) {
        return _resolveAssetType(originalURL);
    }
    
    // Check if the URL path contains HLS-specific extensions.
    return ([URL.path.pathExtension isEqualToString:HLS_EXTENSION_PLAYLIST] ||
            [URL.path.pathExtension isEqualToString:HLS_EXTENSION_SEGMENT] ||
            [URL.path.pathExtension isEqualToString:HLS_EXTENSION_AES_KEY]) ? MCSAssetTypeHLS : MCSAssetTypeFILE;
}

/// Encodes the given URL string into a base64 format.
///
/// @param url The URL string to encode.
/// @return The base64-encoded string.
- (NSString *)encode:(NSString *)url {
    return [[url dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
}

/// Decodes the base64-encoded string back into a URL string.
///
/// @param base64String The base64-encoded string.
/// @return The decoded URL string.
- (NSString *)decode:(NSString *)base64String {
    return [NSString.alloc initWithData:[NSData.alloc initWithBase64EncodedString:base64String options:0] encoding:NSUTF8StringEncoding];
}
@end

@implementation MCSURL (HLS)
- (MCSDataType)dataTypeForHLSProxyURL:(NSURL *)proxyURL {
    NSString *extension = proxyURL.path.pathExtension;
    if ( [extension isEqualToString:HLS_EXTENSION_PLAYLIST] )
        return MCSDataTypeHLSPlaylist;
    
    if ( [extension isEqualToString:HLS_EXTENSION_AES_KEY] )
        return MCSDataTypeHLSAESKey;

    if ( [extension isEqualToString:HLS_EXTENSION_SEGMENT] )
        return MCSDataTypeHLSSegment;
    
    @throw [NSException exceptionWithName:NSGenericException
                                   reason:[NSString stringWithFormat:@"Cannot determine data type for proxy URL: %@", proxyURL.absoluteString]
                                 userInfo:nil];
}

/// The proxyURI format is: mcsproxy/assetName/proxyFilename(urlmd5.extension)?url=base64EncodedUrl(originalUrl)
- (NSString *)generateProxyURIFromHLSOriginalUrl:(NSString *)url extension:(NSString *)extension forAsset:(NSString *)assetName {
    NSString *proxyFilename = [self generateProxyFilenameFromHLSOriginalUrl:url extension:extension];
    NSString *URI = [NSString stringWithFormat:@"%@/%@/%@?url=%@", MCS_PROXY_FLAG, assetName, proxyFilename, [self encode:url]];
    return URI;
}

/// The proxyFilename format is: urlmd5.extension
- (NSString *)generateProxyFilenameFromHLSOriginalUrl:(NSString *)url extension:(NSString *)extension {
    NSString *identifier = MCSMD5(url);
    NSString *filename = [NSString stringWithFormat:@"%@.%@", identifier, extension];
    return filename;
}

- (NSURL *)generateProxyURLFromHLSProxyURI:(NSString *)proxyURI {
    NSAssert(_serverURL != nil, @"The serverURL can't be nil!");
    return [_serverURL mcs_URLByAppendingPathComponent:proxyURI];
}

- (NSURL *)restoreURLFromHLSProxyURI:(NSString *)proxyURI {
    return [self restoreURLFromProxyURL:[NSURL URLWithString:proxyURI]];
}
@end
