//
//  MCSAssetExporterManager.m
//  SJMediaCacheServer
//
//  Created by BD on 2021/3/10.
//

#import "MCSAssetExporterManager.h"
#import "NSFileManager+MCS.h"
#import "MCSPrefetcherManager.h"
   
@interface MCSAssetExporterManager ()
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@end

@implementation MCSAssetExporterManager
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


/// 注册观察者
///
///     导出的相关回调会通知该观察者.
///
- (void)registerObserver:(id<MCSAssetExportObserver>)observer {
    
}

/// 移除观察
///
///     当不需要监听时, 可以调用该方法.
///
///     监听是自动移除的, 在观察者释放时并不需要显示的调用该方法
///
- (void)removeObserver:(id<MCSAssetExportObserver>)observer {
    
}

/// 添加一个导出任务
///
/// \code
///         id<MCSAssetExporter> exporter = [session exportAssetWithURL:URL];
///         // 开启
///         [exporter resume];
/// \endcode
///
- (id<MCSAssetExporter>)exportAssetWithURL:(NSURL *)URL {
    return nil;
}

/// 删除导出的资源
///
- (void)removeAssetWithURL:(NSURL *)URL {
    
}

/// 删除全部
///
- (void)removeAllAssets {
    
}

/// 查询状态
///
- (MCSAssetExportStatus)statusWithURL:(NSURL *)URL {
    return MCSAssetExportStatusUnknown;
}

/// 查询进度
///
- (float)progressWithURL:(NSURL *)URL {
    return 0.0f;
}

/// 获取已导出的资源的播放地址
///
- (nullable NSURL *)playbackURLForExportedAssetWithURL:(NSURL *)URL {
    return nil;
}

/// 同步缓存, 更新缓存进度
///
- (void)synchronizeForAssetWithURL:(NSURL *)URL {
    
}

- (void)synchronize {
    
}
@end

/*
 v2:
    - 需要对缓存管理进行改造
        - asset增加常驻标记
        - removeAllCaches 将不可用
        - 需要重新提供删除相关的方法
        - 需要提供常驻资源占用的缓存
        - 需要提供正常请求占用的缓存
    - 增加syncFromCache方法, 用于同步进度
    - 增加自己的状态
 */
