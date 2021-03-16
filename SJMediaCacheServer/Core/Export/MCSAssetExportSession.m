//
//  MCSAssetExportSession.m
//  SJMediaCacheServer
//
//  Created by BD on 2021/3/10.
//

#import "MCSAssetExportSession.h"
#import "NSFileManager+MCS.h"
#import "MCSPrefetcherManager.h"

@interface MCSAssetExportTask : NSObject<MCSAssetExportTask>
+ (nullable instancetype)taskWithURL:(NSURL *)URL;
@property (nonatomic, strong, readonly, nullable) NSError *error;
@property (nonatomic, readonly) MCSAssetExportStatus status;
@property (nonatomic, readonly) float progress;
@property (nonatomic, copy, nullable) void(^progressCallback)(id<MCSAssetExportTask> task);
@property (nonatomic, copy, nullable) void(^statusDidChangeCallback)(id<MCSAssetExportTask> task);
- (void)resume;     // 恢复
- (void)suspend;    // 暂停, 不删除
- (void)cancel;     // 取消, 并删除
@end

@implementation MCSAssetExportTask {
    NSURL *_URL;
    id<MCSPrefetchTask> _Nullable _prefetcher;
}

+ (instancetype)taskWithURL:(NSURL *)URL {
    if ( URL == nil || URL.isFileURL )
        return nil;
    return [MCSAssetExportTask.alloc initWithURL:URL];
}

- (instancetype)initWithURL:(NSURL *)URL {
    self = [super init];
    if ( self ) {
        _URL = URL;
    }
    return self;
}

- (void)resume {
    
}

- (void)suspend {
    
}

- (void)cancel {
    
}
@end

#pragma mark - mark

@interface MCSAssetExportSession ()
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@end

@implementation MCSAssetExportSession
@synthesize documentRootPath = _documentRootPath;
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
        _operationQueue = NSOperationQueue.alloc.init;
        _operationQueue.maxConcurrentOperationCount = 1;
        _operationQueue.qualityOfService = NSQualityOfServiceBackground;
    }
    return self;
}

- (NSString *)documentRootPath {
    if ( _documentRootPath == nil ) {
        _documentRootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:@"com.SJMediaCacheServer.exports"];
    }
    return _documentRootPath;
}

/// 查询导出进度
- (float)exportProgressForURL:(NSURL *)URL {
    return 0.0f;
}

/// 获取播放地址
- (nullable NSURL *)playbackURLForExportedAssetWithURL:(NSURL *)URL {
    return nil;
}

/// 导出资源
- (nullable id<MCSAssetExportTask>)exportAssetWithURL:(NSURL *)URL {
    return [MCSAssetExportTask taskWithURL:URL];
}
@end
