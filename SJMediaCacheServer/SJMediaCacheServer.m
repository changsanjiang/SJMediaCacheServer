//
//  SJMediaCacheServer.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJMediaCacheServer.h"
#import "MCTcpSocketServer.h"
#import "MCHttpResponse.h"
#import "MCSAssetManager.h"
#import "MCSCacheManager.h"
#import "MCSExporterManager.h"
#import "MCSURL.h"
#import "MCSProxyTask.h"
#import "MCSLogger.h"
#import "MCSDownload.h"
#import "MCSPrefetcherManager.h"

@interface SJMediaCacheServer () {
    MCTcpSocketServer *_server;
}
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
        _server = [MCTcpSocketServer.alloc init];
        _server.onConnect = ^(MCTcpSocketConnection * _Nonnull connection) {
            [MCHttpResponse processConnection:connection];
        };
        _server.onListen = ^(uint16_t port) {
            MCSURL.shared.serverURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%hu", port]];
        };
        
        self.resolveAssetIdentifier = ^NSString * _Nonnull(NSURL * _Nonnull URL) {
            NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
            components.query = nil; // ignore query parameters for identifier purposes
            return components.URL.absoluteString;
        };
    }
    return self;
}

- (nullable NSURL *)proxyURLFromURL:(NSURL *)URL {
    if ( URL == nil )
        return nil;
    
    if ( URL.isFileURL )
        return URL;

    // proxy URL
    if ( _server.isRunning || [_server start] )
        return [MCSURL.shared generateProxyURLFromURL:URL];

    // param URL
    return URL;
}

- (BOOL)isActive {
    return _server.isRunning;
}

- (void)setActive:(BOOL)active {
    active ? [_server start] : [_server stop];
}
@end


@implementation SJMediaCacheServer (Prefetch)

- (void)setMaxConcurrentPrefetchCount:(NSInteger)maxConcurrentPrefetchCount {
    MCSPrefetcherManager.shared.maxConcurrentPrefetchCount = maxConcurrentPrefetchCount;
}
 
- (NSInteger)maxConcurrentPrefetchCount {
    return MCSPrefetcherManager.shared.maxConcurrentPrefetchCount;
}

- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL prefetchSize:(NSUInteger)prefetchSize {
    return [self prefetchWithURL:URL prefetchSize:prefetchSize progress:nil completion:nil];
}

- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL prefetchSize:(NSUInteger)prefetchSize progress:(void(^_Nullable)(float progress))progressBlock completion:(void(^_Nullable)(NSError *_Nullable error))completionHandler {
    if ( URL != nil ) {
        if ( _server.isRunning || [_server start] ) {
            return [MCSPrefetcherManager.shared prefetchWithURL:URL prefetchSize:prefetchSize progress:progressBlock completion:completionHandler];
        }
    }
    return nil;
}

- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL progress:(void(^_Nullable)(float progress))progressBlock completion:(void(^_Nullable)(NSError *_Nullable error))completionHandler {
    if ( URL != nil ) {
        if ( _server.isRunning || [_server start] ) {
            return [MCSPrefetcherManager.shared prefetchWithURL:URL progress:progressBlock completion:completionHandler];
        }
    }
    return nil;
}

- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL prefetchFileCount:(NSUInteger)num progress:(void(^_Nullable)(float progress))progressBlock completion:(void(^_Nullable)(NSError *_Nullable error))completionHandler {
    if ( URL != nil ) {
        if ( _server.isRunning || [_server start] ) {
            return [MCSPrefetcherManager.shared prefetchWithURL:URL prefetchFileCount:num progress:progressBlock completion:completionHandler];
        }
    }
    return nil;
}

- (void)cancelAllPrefetchTasks {
    [MCSPrefetcherManager.shared cancelAllPrefetchTasks];
}

@end


@implementation SJMediaCacheServer (Request)

- (void)setSessionConfiguration:(NSURLSessionConfiguration *)sessionConfiguration {
    MCSDownload.shared.initialSessionConfiguration = sessionConfiguration;
}

- (nullable NSURLSessionConfiguration *)sessionConfiguration {
    return MCSDownload.shared.initialSessionConfiguration;
}

- (void)setRequestHandler:(void (^)(NSMutableURLRequest * _Nonnull))requestHandler {
    MCSDownload.shared.requestHandler = requestHandler;
}
- (void (^)(NSMutableURLRequest * _Nonnull))requestHandler {
    return MCSDownload.shared.requestHandler;
}

- (void)setHTTPHeaderField:(NSString *)field withValue:(nullable NSString *)value forAssetURL:(NSURL *)URL ofType:(MCSDataType)type {
    if ( URL != nil && field != nil ) {
        id<MCSAsset> asset = [MCSAssetManager.shared assetWithURL:URL];
        [asset.configuration setValue:value forHTTPAdditionalHeaderField:field ofType:type];
    }
}
- (nullable NSDictionary<NSString *, NSString *> *)HTTPAdditionalHeadersForAssetURL:(NSURL *)URL ofType:(MCSDataType)type {
    if ( URL != nil ) {
        id<MCSAsset> asset = [MCSAssetManager.shared assetWithURL:URL];
        return [asset.configuration HTTPAdditionalHeadersForDataRequestsOfType:type];
    }
    return nil;
}

- (void)setMetricsHandler:(void (^_Nullable)(NSURLSession * _Nonnull, NSURLSessionTask * _Nonnull, NSURLSessionTaskMetrics * _Nonnull))metricsHandler {
    MCSDownload.shared.metricsHandler = metricsHandler;
}

- (void (^_Nullable)(NSURLSession * _Nonnull, NSURLSessionTask * _Nonnull, NSURLSessionTaskMetrics * _Nonnull))metricsHandler {
    return MCSDownload.shared.metricsHandler;
}
@end



@implementation SJMediaCacheServer (Convert)

- (void)setResolveAssetType:(MCSAssetType (^)(NSURL * _Nonnull))resolveAssetType {
    MCSURL.shared.resolveAssetType = resolveAssetType;
}
- (MCSAssetType (^)(NSURL * _Nonnull))resolveAssetType {
    return MCSURL.shared.resolveAssetType;
}

- (void)setResolveAssetIdentifier:(NSString * _Nonnull (^)(NSURL * _Nonnull))resolveAssetIdentifier {
    MCSURL.shared.resolveAssetIdentifier = resolveAssetIdentifier;
}
- (NSString * _Nonnull (^)(NSURL * _Nonnull))resolveAssetIdentifier {
    return MCSURL.shared.resolveAssetIdentifier;
}

- (void)setWriteDataEncryptor:(NSData * _Nonnull (^)(NSURLRequest * _Nonnull, NSUInteger, NSData * _Nonnull))writeDataEncryptor {
    MCSDownload.shared.receivedDataEncryptor = writeDataEncryptor;
}
- (NSData * _Nonnull (^)(NSURLRequest * _Nonnull, NSUInteger, NSData * _Nonnull))writeDataEncryptor {
    return MCSDownload.shared.receivedDataEncryptor;
}

- (void)setReadDataDecryptor:(NSData * _Nonnull (^)(NSURLRequest * _Nonnull, NSUInteger, NSData * _Nonnull))readDataDecryptor {
    MCSAssetManager.shared.readDataDecryptor = readDataDecryptor;
}
- (NSData * _Nonnull (^)(NSURLRequest * _Nonnull, NSUInteger, NSData * _Nonnull))readDataDecryptor {
    return MCSAssetManager.shared.readDataDecryptor;
}
@end


@implementation SJMediaCacheServer (Log)

- (void)setEnabledConsoleLog:(BOOL)enabledConsoleLog {
    MCSLogger.shared.enabledConsoleLog = enabledConsoleLog;
}

- (BOOL)isEnabledConsoleLog {
    return MCSLogger.shared.enabledConsoleLog;
}

- (void)setLogOptions:(MCSLogOptions)logOptions {
    MCSLogger.shared.options = logOptions;
}

- (MCSLogOptions)logOptions {
    return MCSLogger.shared.options;
}

- (void)setLogLevel:(MCSLogLevel)logLevel {
    MCSLogger.shared.level = logLevel;
}

- (MCSLogLevel)logLevel {
    return MCSLogger.shared.level;
}
@end

@implementation SJMediaCacheServer (Cache)
- (void)setCacheCountLimit:(NSUInteger)cacheCountLimit {
    MCSCacheManager.shared.cacheCountLimit = cacheCountLimit;
}

- (NSUInteger)cacheCountLimit {
    return MCSCacheManager.shared.cacheCountLimit;
}

- (void)setCacheMaxDiskAge:(NSTimeInterval)cacheMaxDiskAge {
    MCSCacheManager.shared.cacheMaxDiskAge = cacheMaxDiskAge;
}
- (NSTimeInterval)cacheMaxDiskAge {
    return MCSCacheManager.shared.cacheMaxDiskAge;
}

- (void)setCacheMaxDiskSize:(NSUInteger)cacheMaxDiskSize {
    MCSCacheManager.shared.cacheMaxDiskSize = cacheMaxDiskSize;
}
- (NSUInteger)cacheMaxDiskSize {
    return MCSCacheManager.shared.cacheMaxDiskSize;
}

- (void)setCacheReservedFreeDiskSpace:(NSUInteger)cacheReservedFreeDiskSpace {
    MCSCacheManager.shared.cacheReservedFreeDiskSpace = cacheReservedFreeDiskSpace;
}
- (NSUInteger)cacheReservedFreeDiskSpace {
    return MCSCacheManager.shared.cacheReservedFreeDiskSpace;
}

- (void)removeAllCaches {
    [MCSCacheManager.shared removeUnprotectedCaches];
}

- (BOOL)removeCacheForURL:(NSURL *)URL {
    return [MCSCacheManager.shared removeCacheForURL:URL];
}

- (UInt64)countOfBytesAllCaches {
    return MCSCacheManager.shared.countOfBytesUnprotectedCaches;
}

- (BOOL)isFullyStoredAssetForURL:(NSURL *)URL {
    return URL != nil ? [MCSAssetManager.shared isAssetStoredForURL:URL] : NO;
}
@end

@implementation SJMediaCacheServer (Export)

- (void)registerExportObserver:(id<MCSExportObserver>)observer {
    [MCSExporterManager.shared registerObserver:observer];
}
 
- (void)removeExportObserver:(id<MCSExportObserver>)observer {
    [MCSExporterManager.shared removeObserver:observer];
}

- (void)setMaxConcurrentExportCount:(NSInteger)maxConcurrentExportCount {
    MCSExporterManager.shared.maxConcurrentExportCount = maxConcurrentExportCount;
}

- (NSInteger)maxConcurrentExportCount {
    return MCSExporterManager.shared.maxConcurrentExportCount;
}

- (nullable NSArray<id<MCSExporter>> *)allExporters {
    return MCSExporterManager.shared.allExporters;
}

- (nullable NSArray<id<MCSExporter>> *)exportersForMask:(MCSExportStatusQueryMask)mask {
    return [MCSExporterManager.shared exportersForMask:mask];
}

- (nullable id<MCSExporter>)exportAssetWithURL:(NSURL *)URL {
    return [self exportAssetWithURL:URL shouldResume:NO];
}

- (nullable id<MCSExporter>)exportAssetWithURL:(NSURL *)URL shouldResume:(BOOL)shouldResume {
    if ( URL != nil ) {
        if ( _server.isRunning || [_server start] ) {
            id<MCSExporter> exporter = [MCSExporterManager.shared exportAssetWithURL:URL];
            if ( shouldResume ) [exporter resume];
            return exporter;
        }
    }
    return nil;
}
 
- (MCSExportStatus)exportStatusForURL:(NSURL *)URL {
    return [MCSExporterManager.shared statusForURL:URL];
}

- (float)exportProgressForURL:(NSURL *)URL {
    return [MCSExporterManager.shared progressForURL:URL];
}

- (void)synchronizeProgressForExporterWithURL:(NSURL *)URL {
    [MCSExporterManager.shared synchronizeProgressForExporterWithURL:URL];
}

- (void)synchronizeProgressForExporters {
    [MCSExporterManager.shared synchronize];
}

- (UInt64)countOfBytesAllExportedAssets {
    return [MCSExporterManager.shared countOfBytesAllExportedAssets];
}

- (void)removeExportAssetWithURL:(NSURL *)URL {
    [MCSExporterManager.shared removeAssetWithURL:URL];
}

- (void)removeAllExportAssets {
    [MCSExporterManager.shared removeAllAssets];
}
@end
