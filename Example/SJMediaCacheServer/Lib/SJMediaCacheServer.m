//
//  SJMediaCacheServer.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJMediaCacheServer.h"
#import "MCSProxyServer.h"
#import "MCSResourceManager.h"
#import "MCSResource.h"
#import "MCSURLRecognizer.h"
#import "MCSSessionTask.h"

@interface SJMediaCacheServer ()<MCSProxyServerDelegate>
@property (nonatomic, strong, readonly) MCSProxyServer *server;
@end

@implementation SJMediaCacheServer
+ (instancetype)shared {
    static id obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[self alloc] init];
    });
    return obj;
}

- (instancetype)init {
    self = [super init];
    if ( self ) {
        _server = [MCSProxyServer.alloc initWithPort:2000];
        _server.delegate = self;
        [_server start];
    }
    return self;
}

- (NSURL *)playbackURLWithURL:(NSURL *)URL {
    if ( URL.isFileURL )
        return URL;
    MCSResource *resource = [MCSResourceManager.shared resourceWithURL:URL];
    
    // playback URL for cache
    if ( resource.isCacheFinished )
        return [resource playbackURLForCacheWithURL:URL];
    
    // proxy URL
    if ( _server.isRunning )
        return [MCSURLRecognizer.shared proxyURLWithURL:URL localServerURL:_server.serverURL];

    // param URL
    return URL;
}

#pragma mark - MCSProxyServerDelegate

- (id<MCSSessionTask>)server:(MCSProxyServer *)server taskWithRequest:(NSURLRequest *)request delegate:(id<MCSSessionTaskDelegate>)delegate {
    return [MCSSessionTask.alloc initWithRequest:request delegate:delegate];
}
@end


@implementation SJMediaCacheServer (Cache)
- (void)setCacheCountLimit:(NSUInteger)cacheCountLimit {
    MCSResourceManager.shared.cacheCountLimit = cacheCountLimit;
}

- (NSUInteger)cacheCountLimit {
    return MCSResourceManager.shared.cacheCountLimit;
}

- (void)setMaxDiskAgeForCache:(NSTimeInterval)maxDiskAgeForCache {
    MCSResourceManager.shared.maxDiskAgeForCache = maxDiskAgeForCache;
}
- (NSTimeInterval)maxDiskAgeForCache {
    return MCSResourceManager.shared.maxDiskAgeForCache;
}

- (void)setMaxDiskSizeForCache:(NSUInteger)maxDiskSizeForCache {
    MCSResourceManager.shared.maxDiskSizeForCache = maxDiskSizeForCache;
}
- (NSUInteger)maxDiskSizeForCache {
    return MCSResourceManager.shared.maxDiskSizeForCache;
}

- (void)setReservedFreeDiskSpace:(NSUInteger)reservedFreeDiskSpace {
    MCSResourceManager.shared.reservedFreeDiskSpace = reservedFreeDiskSpace;
}
- (NSUInteger)reservedFreeDiskSpace {
    return MCSResourceManager.shared.reservedFreeDiskSpace;
}

- (void)removeAllCaches {
    [MCSResourceManager.shared removeAllCaches];
}
@end
