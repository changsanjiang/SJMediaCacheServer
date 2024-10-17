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

    // hls 内部代理请求
    // format: mcsproxy/asset/name.extension?url=base64EncodedUrl
    if ( [originalURL.path containsString:MCS_PROXY_FLAG] ) return originalURL;
    if ( [originalURL.host isEqualToString:_serverURL.host] ) return originalURL;

    NSURL *serverURL = _serverURL;
    NSURLComponents *components = [NSURLComponents componentsWithURL:serverURL resolvingAgainstBaseURL:NO];
    [components setQuery:[NSString stringWithFormat:@"url=%@", [self encode:originalURL.absoluteString]]];
    components.path = originalURL.path;
    return components.URL;
}

- (NSURL *)restoreURLFromProxyURL:(NSURL *)proxyURL {
    NSAssert(_serverURL != nil, @"The serverURL can't be nil!");

    if ( [proxyURL.host isEqualToString:_serverURL.host] ) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:proxyURL resolvingAgainstBaseURL:NO];
        for ( NSURLQueryItem *query in components.queryItems ) {
            if ( [query.name isEqualToString:@"url"] ) {
                NSString *url = [self decode:query.value];
                return [NSURL URLWithString:url];
            }
        }
    }
    return proxyURL;
}

// URL: `proxyURL or originalURL`
- (NSString *)getAssetNameBy:(NSURL *)URL {
    NSAssert(_serverURL != nil, @"The serverURL can't be nil!");

    NSParameterAssert(URL.host);
    
    if ( [URL.path containsString:MCS_PROXY_FLAG] ) {
        // 包含 mcsproxy 为 HLS 内部资源的请求, 此处返回path后面资源的名字
        // format: mcsproxy/asset/name.extension?url=base64EncodedUrl
        return URL.path.stringByDeletingLastPathComponent.lastPathComponent;
    }
    
    // assetName 正常情况下是 originalURL 的 md5 值
    // 不包含 mcsproxy 时, 将代理URL转换为原始的URL
    NSURL *originalURL = [self restoreURLFromProxyURL:URL];
    NSString *assetIdentifier = self.resolveAssetIdentifier != nil ? self.resolveAssetIdentifier(originalURL) : originalURL.absoluteString;
    NSParameterAssert(assetIdentifier);
    NSString *assetName = MCSMD5(assetIdentifier);
    return assetName;
}

- (MCSAssetType)getAssetTypeBy:(NSURL *)URL {
    NSURL *originalURL = [self restoreURLFromProxyURL:URL];
    if ( _resolveAssetType != nil ) return _resolveAssetType(originalURL);
    
    return [URL.path containsString:HLS_SUFFIX_INDEX] ||
           [URL.path containsString:HLS_SUFFIX_TS] ||
           [URL.path containsString:HLS_SUFFIX_AES_KEY] ? MCSAssetTypeHLS : MCSAssetTypeFILE;
}

- (NSString *)encode:(NSString *)url {
    return [[url dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
}

- (NSString *)decode:(NSString *)url {
    return [NSString.alloc initWithData:[NSData.alloc initWithBase64EncodedString:url options:0] encoding:NSUTF8StringEncoding];
}








- (MCSDataType)dataTypeForProxyURL:(NSURL *)proxyURL {
    NSString *last = proxyURL.lastPathComponent;
    if ( [last containsString:HLS_SUFFIX_INDEX] )
        return MCSDataTypeHLSPlaylist;
    
    if ( [last containsString:HLS_SUFFIX_AES_KEY] )
        return MCSDataTypeHLSAESKey;

    if ( [last containsString:HLS_SUFFIX_TS] )
        return MCSDataTypeHLSSegment;
    
    return MCSDataTypeFILE;
}

- (NSString *)nameWithUrl:(NSString *)url suffix:(NSString *)suffix {
    NSString *filename = url.mcs_fname;
    // 添加扩展名
    if ( ![filename hasSuffix:suffix] )
        filename = [filename stringByAppendingString:suffix];
    return filename;
}

- (NSURL *)proxyURLWithRelativePath:(NSString *)path inAsset:(NSString *)assetName {
    // format: mcsproxy/asset/path
    return [_serverURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/%@", MCS_PROXY_FLAG, assetName, path]];
}


- (NSURLQueryItem *)encodedURLQueryItemWithUrl:(NSString *)url {
    return [NSURLQueryItem.alloc initWithName:@"url" value:[self encode:url]];
}

- (NSString *)proxyFilenameWithOriginalURL:(NSURL *)originalURL dataType:(MCSDataType)dataType {
    NSString *name = originalURL.mcs_fname;
    NSString *extension = originalURL.mcs_extension;
    return extension.length > 0 ? [NSString stringWithFormat:@"%@_%ld.%@", name, dataType, extension] : name;
}
@end

@implementation MCSURL (HLS)
// format: mcsproxy/asset/name.extension?url=base64EncodedUrl
- (NSString *)HLS_proxyURIWithURL:(NSString *)url suffix:(NSString *)suffix inAsset:(NSString *)asset {
    NSString *fname = [self nameWithUrl:url suffix:suffix];
    NSURLQueryItem *query = [self encodedURLQueryItemWithUrl:url];
    NSString *URI = [NSString stringWithFormat:@"%@/%@/%@?%@=%@", MCS_PROXY_FLAG, asset, fname, query.name, query.value];
    return URI;
}

- (NSURL *)HLS_URLWithProxyURI:(NSString *)proxyURI {
    return [self restoreURLFromProxyURL:[NSURL URLWithString:proxyURI]];
}

- (NSURL *)HLS_proxyURLWithProxyURI:(NSString *)uri {
    NSAssert(_serverURL != nil, @"The serverURL can't be nil!");
    
    return [_serverURL mcs_URLByAppendingPathComponent:uri];
}
@end
