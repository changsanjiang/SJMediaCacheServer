//
//  MCSAssetExporterManager.m
//  SJMediaCacheServer
//
//  Created by BD on 2021/3/10.
//

#import "MCSAssetExporterManager.h"
#import "MCSPrefetcherManager.h"
#import "MCSAssetManager.h"
#import "MCSDatabase.h"
#import "MCSURL.h"
#import "MCSUtils.h"

@interface MCSAssetExporter : NSObject<MCSSaveable, MCSAssetExporter>
- (instancetype)initWithURLString:(NSString *)URLStr name:(NSString *)name type:(MCSAssetType)type;
@property (nonatomic, strong, readonly) NSURL *URL;
@property (nonatomic) MCSAssetExportStatus status;
@property (nonatomic) float progress;
- (void)synchronize;
- (void)resume;
- (void)suspend;
- (void)cancel;
@end

@interface MCSAssetExporter () {
    dispatch_semaphore_t _semaphore;
}
@property (nonatomic) NSInteger id;
@property (nonatomic, strong) NSString *name; // asset name
@property (nonatomic, strong) NSString *URLString;
@property (nonatomic) MCSAssetType type;
@end

@implementation MCSAssetExporter
@synthesize URL = _URL;
@synthesize status = _status;
@synthesize progress = _progress;

- (instancetype)initWithURLString:(NSString *)URLStr name:(NSString *)name type:(MCSAssetType)type {
    self = [self init];
    if ( self ) {
        _URLString = URLStr;
        _name = name;
        _type = type;
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if ( self ) {
        _semaphore = dispatch_semaphore_create(1);
    }
    return self;
}

+ (NSString *)sql_primaryKey {
    return @"id";
}

+ (NSArray<NSString *> *)sql_autoincrementlist {
    return @[self.sql_primaryKey];
}

+ (NSArray<NSString *> *)sql_blacklist {
    return @[@"URL"];
}

- (NSURL *)URL {
    __block NSURL *URL = nil;
    [self _lockInBlock:^{
        if ( _URL == nil )
            _URL = [NSURL URLWithString:_URLString];
        URL = _URL;
    }];
    return URL;
}
  
#warning next ....
- (MCSAssetExportStatus)status {
    __block MCSAssetExportStatus status;
    [self _lockInBlock:^{
        status = _status;
    }];
    return status;
}
#warning next ...
//@property (nonatomic, readonly) float progress;

- (void)synchronize {
    
}

- (void)resume {
    
}

- (void)suspend {
    
}

- (void)cancel {
    
}

- (void)_lockInBlock:(void(^NS_NOESCAPE)(void))task {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    task();
    dispatch_semaphore_signal(_semaphore);
}
@end
   

@interface MCSAssetExporterManager () {
    SJSQLite3 *_sqlite3;
    NSHashTable<id<MCSAssetExportObserver>> *_Nullable _observers;
    dispatch_semaphore_t _semaphore;
    NSMutableArray<MCSAssetExporter *> *_exporters;
}
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
        _semaphore = dispatch_semaphore_create(1);

        _sqlite3 = MCSDatabase();
        NSArray<MCSAssetExporter *> *results = [_sqlite3 objectsForClass:MCSAssetExporter.class conditions:nil orderBy:@[
            [SJSQLite3ColumnOrder orderWithColumn:@"id" ascending:NO]
        ] error:NULL];
        if ( results.count != 0 ) {
            NSMutableArray<MCSAssetExporter *> *needsToPause = NSMutableArray.array;
            for ( MCSAssetExporter *exporter in results ) {
                switch ( exporter.status ) {
                    case MCSAssetExportStatusUnknown:
                    case MCSAssetExportStatusFinished:
                    case MCSAssetExportStatusFailed:
                    case MCSAssetExportStatusSuspended:
                    case MCSAssetExportStatusCancelled:
                        break;
                    case MCSAssetExportStatusWaiting:
                    case MCSAssetExportStatusExporting: {
                        exporter.status = MCSAssetExportStatusSuspended;
                        [needsToPause addObject:exporter];
                    }
                        break;
                }
            }
            [_sqlite3 updateObjects:needsToPause forKeys:@[@"status"] error:NULL];
        }
        _exporters = results.count != 0 ? results.mutableCopy : NSMutableArray.array;
    }
    return self;
}

/// 注册观察者
///
///     导出的相关回调会通知该观察者.
///
- (void)registerObserver:(id<MCSAssetExportObserver>)observer {
    if ( observer == nil )
        return;
    [self _lockInBlock:^{
        if ( _observers == nil ) {
            _observers = NSHashTable.weakObjectsHashTable;
        }
        [_observers addObject:observer];
    }];
}

/// 移除观察
///
///     当不需要监听时, 可以调用该方法.
///
///     监听是自动移除的, 在观察者释放时并不需要显示的调用该方法
///
- (void)removeObserver:(id<MCSAssetExportObserver>)observer {
    if ( observer == nil )
        return;
    [self _lockInBlock:^{
        [_observers removeObject:observer];
    }];
}

/// 添加一个导出任务
///
/// \code
///         id<MCSAssetExporter> exporter = [session exportAssetWithURL:URL];
///         // 开启
///         [exporter resume];
/// \endcode
///
- (nullable id<MCSAssetExporter>)exportAssetWithURL:(NSURL *)URL {
    if ( URL.absoluteString.length == 0 )
        return nil;
    __block MCSAssetExporter *exporter = nil;
    [self _lockInBlock:^{
        exporter = [self _exportAssetWithURL:URL];
    }];
    return exporter;
}

/// 删除导出的资源
///
- (void)removeAssetWithURL:(NSURL *)URL {
    if ( URL.absoluteString.length == 0 )
        return;
    
    __block BOOL isRemoved = NO;
    [self _lockInBlock:^{
        NSString *name = [MCSURL.shared assetNameForURL:URL];
        MCSAssetExporter *_Nullable exporter = [self _exporterInMemoryForName:name];
        if ( exporter != nil ) {
            [_exporters removeObject:exporter];
            [URL mcs_setShouldHoldCache:NO];
            [_sqlite3 removeObjectForClass:MCSAssetExporter.class primaryKeyValue:@(exporter.id) error:NULL];
            [MCSAssetManager.shared removeAssetForURL:URL];
            isRemoved = YES;
        }
    }];
    
    if ( isRemoved ) {
        for ( id<MCSAssetExportObserver> observer in MCSAllHashTableObjects(_observers) ) {
            if ( [observer respondsToSelector:@selector(exporterManagerDidRemoveAssetWithURL:)] ) {
                [observer exporterManagerDidRemoveAssetWithURL:URL];
            }
        }
    }
}

/// 删除全部
///
- (void)removeAllAssets {
    __block BOOL isRemoved = NO;
    [self _lockInBlock:^{
        if ( _exporters.count != 0 ) {
            NSArray<MCSAssetExporter *> *exporters = _exporters.copy;
            [_exporters removeAllObjects];
            [_sqlite3 removeAllObjectsForClass:MCSAssetExporter.class error:NULL];
            for ( MCSAssetExporter *exporter in exporters ) {
                id<MCSAsset> asset = [MCSAssetManager.shared assetWithName:exporter.name type:exporter.type];
                [MCSAssetManager.shared asset:asset setShouldHoldCache:NO];
                [MCSAssetManager.shared removeAsset:asset];
            }
            isRemoved = YES;
        }
    }];
    
    if ( isRemoved ) {
        for ( id<MCSAssetExportObserver> observer in MCSAllHashTableObjects(_observers) ) {
            if ( [observer respondsToSelector:@selector(exporterManagerDidRemoveAllAssets)] ) {
                [observer exporterManagerDidRemoveAllAssets];
            }
        }
    }
}

/// 查询状态
///
- (MCSAssetExportStatus)statusWithURL:(NSURL *)URL {
    __block MCSAssetExportStatus status = MCSAssetExportStatusUnknown;
    if ( URL.absoluteString.length != 0 ) {
        [self _lockInBlock:^{
            NSString *name = [MCSURL.shared assetNameForURL:URL];
            MCSAssetExporter *exporter = [self _exporterInMemoryForName:name];
            status = exporter.status;
        }];
    }
    return status;
}

/// 查询进度
///
- (float)progressWithURL:(NSURL *)URL {
    __block float progress = 0.0f;
    if ( URL.absoluteString.length != 0 ) {
        [self _lockInBlock:^{
            NSString *name = [MCSURL.shared assetNameForURL:URL];
            MCSAssetExporter *exporter = [self _exporterInMemoryForName:name];
            progress = exporter.progress;
        }];
    }
    return progress;
}

/// 获取已导出的资源的播放地址
///
- (nullable NSURL *)playbackURLForExportedAssetWithURL:(NSURL *)URL {
    if ( URL.absoluteString.length == 0 )
        return nil;

#warning next ...
    return nil;
}

/// 同步缓存, 更新缓存进度
///
- (void)synchronizeForAssetWithURL:(NSURL *)URL {
    if ( URL.absoluteString.length != 0 ) {
        [self _lockInBlock:^{
            NSString *name = [MCSURL.shared assetNameForURL:URL];
            MCSAssetExporter *exporter = [self _exporterInMemoryForName:name];
            [exporter synchronize];
        }];
    }
}

- (void)synchronize {
    [self _lockInBlock:^{
        for ( MCSAssetExporter *exporter in _exporters ) {
            [exporter synchronize];
        }
    }];
}

#pragma mark - mark

- (void)_lockInBlock:(void(^NS_NOESCAPE)(void))task {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    task();
    dispatch_semaphore_signal(_semaphore);
}

- (MCSAssetExporter *)_exportAssetWithURL:(NSURL *)URL {
    NSString *name = [MCSURL.shared assetNameForURL:URL];
    MCSAssetType type = [MCSURL.shared assetTypeForURL:URL];
    MCSAssetExporter *exporter = [self _exporterInMemoryForName:name];
    if ( exporter == nil ) {
        exporter = [MCSAssetExporter.alloc initWithURLString:URL.absoluteString name:name type:type];
        [_sqlite3 save:exporter error:NULL];
        [_exporters addObject:exporter];
    }
    return exporter;
}

- (nullable MCSAssetExporter *)_exporterInMemoryForName:(NSString *)name {
    for ( MCSAssetExporter *exporter in _exporters ) {
        if ( [exporter.name isEqualToString:name] )
            return exporter;
    }
    return nil;
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
