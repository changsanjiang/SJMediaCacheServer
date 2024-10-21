//
//  MCSAssetExporterManager.m
//  SJMediaCacheServer
//
//  Created by BD on 2021/3/10.
//

#import "MCSAssetExporterManager.h"
#import "MCSAssetExporter.h"
#import "MCSCacheManager.h"
#import "MCSAssetManager.h"
#import "MCSPrefetcherManager.h"
#import "NSFileManager+MCS.h"
#import "MCSDatabase.h"
#import "MCSURL.h"
#import "MCSUtils.h"
#import "FILEAsset.h"
#import "HLSAsset.h"
#import "MCSError.h"

@interface MCSAssetExporterManager ()<MCSAssetExporterDelegate> {
    SJSQLite3 *mSqlite3;
    NSHashTable<id<MCSAssetExportObserver>> *_Nullable mObservers;
    NSMutableDictionary<NSString *, MCSAssetExporter *> *mExporters;
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
        mExporters = NSMutableDictionary.dictionary;
        mSqlite3 = MCSDatabase();
    }
    return self;
}

- (void)setMaxConcurrentExportCount:(NSInteger)maxConcurrentExportCount {
    MCSPrefetcherManager.shared.maxConcurrentPrefetchCount = maxConcurrentExportCount;
}

- (NSInteger)maxConcurrentExportCount {
    return MCSPrefetcherManager.shared.maxConcurrentPrefetchCount;
}

- (nullable NSArray<id<MCSAssetExporter>> *)allExporters {
    NSArray<id<MCSAssetExporter>> *allExporters = nil;
    @synchronized (self) {
        // memory
        NSMutableArray<NSNumber *> *memoryExporterIds = mExporters.count != 0 ? ([NSMutableArray arrayWithCapacity:mExporters.count]) : nil;
        [mExporters enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, MCSAssetExporter * _Nonnull exporter, BOOL * _Nonnull stop) {
            [memoryExporterIds addObject:@(exporter.id)];
        }];
        
        // disk
        NSArray<SJSQLite3Condition *> *conditions = nil;
        if ( memoryExporterIds.count != 0 ) {
            conditions = @[[SJSQLite3Condition conditionWithColumn:@"id" notIn:memoryExporterIds]];
        }
        NSArray<MCSAssetExporter *> *diskExporters = [mSqlite3 objectsForClass:MCSAssetExporter.class conditions:conditions orderBy:nil error:NULL];
        if ( diskExporters.count != 0 ) {
            [diskExporters enumerateObjectsUsingBlock:^(MCSAssetExporter * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                mExporters[obj.name] = obj;
            }];
        }
        
        // results
        if ( mExporters.count != 0 ) {
            allExporters = mExporters.allValues;
        }
    }
    return allExporters;
}

- (UInt64)countOfBytesAllExportedAssets {
    @synchronized (self) {
        // 暂时可以这么写
        return MCSCacheManager.shared.countOfBytesAllCaches - MCSCacheManager.shared.countOfBytesUnprotectedCaches;
    }
}

/// 注册观察者
///
///     导出的相关回调会通知该观察者.
///
- (void)registerObserver:(id<MCSAssetExportObserver>)observer {
    if ( observer != nil ) {
        @synchronized (self) {
            if ( mObservers == nil ) {
                mObservers = NSHashTable.weakObjectsHashTable;
            }
            [mObservers addObject:observer];
        }
    }
}

/// 移除观察
///
///     当不需要监听时, 可以调用该方法移除监听.
///
///     监听是自动移除的, 在观察者释放时并不需要显示的调用该方法
///
- (void)removeObserver:(id<MCSAssetExportObserver>)observer {
    if ( observer != nil ) {
        @synchronized (self) {
            [mObservers removeObject:observer];
        }
    }
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
    if ( URL != nil ) {
        @synchronized (self) {
            return [self _ensureExporterForURL:URL];
        }
    }
    return nil;
}

/// 删除导出的资源
///
- (void)removeAssetWithURL:(NSURL *)URL {
    if ( URL != nil ) {
        @synchronized (self) {
            NSString *name = [MCSURL.shared assetNameForURL:URL];
            MCSAssetExporter *_Nullable exporter = [self _queryExporterForName:name];
            if ( exporter != nil ) {
                [exporter cancel];
                mExporters[exporter.name] = nil;
                [mSqlite3 removeObjectForClass:MCSAssetExporter.class primaryKeyValue:@(exporter.id) error:NULL];
                [MCSCacheManager.shared setProtected:NO forCacheWithURL:URL];
                [MCSCacheManager.shared removeCacheForURL:URL];
                
                for ( id<MCSAssetExportObserver> observer in MCSAllHashTableObjects(mObservers) ) {
                    if ( [observer respondsToSelector:@selector(exporterManager:didRemoveAssetWithURL:)] ) {
                        [observer exporterManager:self didRemoveAssetWithURL:URL];
                    }
                }
            }
        }
    }
    
}

/// 删除全部
///
- (void)removeAllAssets {
    @synchronized (self) {
        NSMutableArray<NSNumber *> *memoryExporterIds = mExporters.count != 0 ? ([NSMutableArray arrayWithCapacity:mExporters.count]) : nil;
        for ( MCSAssetExporter *exporter in mExporters ) {
            [memoryExporterIds addObject:@(exporter.id)];
        }
        
        NSArray<SJSQLite3Condition *> *conditions = nil;
        if ( memoryExporterIds.count != 0 ) {
            conditions = @[[SJSQLite3Condition conditionWithColumn:@"id" notIn:memoryExporterIds]];
        }
        NSArray<MCSAssetExporter *> *disk = [mSqlite3 objectsForClass:MCSAssetExporter.class conditions:conditions orderBy:nil error:NULL];
        NSArray<MCSAssetExporter *> *memo = mExporters.allValues;
        
        NSMutableArray<MCSAssetExporter *> *allExporters = [NSMutableArray arrayWithCapacity:disk.count + memo.count];
        if ( disk.count != 0 ) {
            [allExporters addObjectsFromArray:disk];
        }
        
        if ( memo.count != 0 ) {
            [allExporters addObjectsFromArray:memo];
        }
        
        if ( allExporters.count != 0 ) {
            for ( MCSAssetExporter *exporter in allExporters ) {
                [exporter cancel];
                id<MCSAsset> asset = [MCSAssetManager.shared assetWithName:exporter.name type:exporter.type];
                [MCSCacheManager.shared setProtected:NO forCacheWithAsset:asset];
                [MCSCacheManager.shared removeCacheForAsset:asset];
            }
            [mExporters removeAllObjects];
            [mSqlite3 removeAllObjectsForClass:MCSAssetExporter.class error:NULL];
            for ( id<MCSAssetExportObserver> observer in MCSAllHashTableObjects(mObservers) ) {
                if ( [observer respondsToSelector:@selector(exporterManagerDidRemoveAllAssets:)] ) {
                    [observer exporterManagerDidRemoveAllAssets:self];
                }
            }
        }
    }
}

/// 查询状态
///
- (MCSAssetExportStatus)statusWithURL:(NSURL *)URL {
    @synchronized (self) {
        NSString *name = [MCSURL.shared assetNameForURL:URL];
        MCSAssetExporter *exporter = [self _queryExporterForName:name];
        return exporter != nil ? exporter.status : MCSAssetExportStatusUnknown;
    }
}

/// 查询进度
///
- (float)progressWithURL:(NSURL *)URL {
    @synchronized (self) {
        NSString *name = [MCSURL.shared assetNameForURL:URL];
        MCSAssetExporter *exporter = [self _queryExporterForName:name];
        return exporter != nil ? exporter.progress : 0;
    }
}


/// 同步缓存, 更新缓存进度
///
- (void)synchronizeForExporterWithAssetURL:(NSURL *)URL {
    if ( URL != nil ) {
        @synchronized (self) {
            NSString *name = [MCSURL.shared assetNameForURL:URL];
            MCSAssetExporter *exporter = [self _queryExporterForName:name];
            [exporter synchronize];
        }
    }
}

- (void)synchronize {
    @synchronized (self) {
        [mExporters enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, MCSAssetExporter * _Nonnull exporter, BOOL * _Nonnull stop) {
            [exporter synchronize];
        }];
    }
}

- (nullable NSArray<id<MCSAssetExporter>> *)queryExportersForMask:(MCSAssetExportStatusQueryMask)mask {
    @synchronized (self) {
        return [self _queryExportersForMask:mask];
    }
}

#pragma mark - MCSAssetExporterDelegate

- (void)exporter:(MCSAssetExporter *)exporter statusDidChange:(MCSAssetExportStatus)status {
    @synchronized (self) {
        if ( status == MCSAssetExportStatusCancelled ) {
            id<MCSAsset> asset = [MCSAssetManager.shared assetWithName:exporter.name type:exporter.type];
            [MCSCacheManager.shared setProtected:NO forCacheWithAsset:asset];
            [mSqlite3 removeObjectForClass:MCSAssetExporter.class primaryKeyValue:@(exporter.id) error:NULL];
            mExporters[exporter.name] = nil;
        }
        else {
            /// 将状态同步数据库
            ///
            /// 状态处于 Waiting, Exporting 时不需要同步至数据库, 仅维护 exporter 在内存中的状态即可.
            /// 当再次启动App时, 状态将在 Suspended, Failed, Finished 之间.
            ///
            switch ( exporter.status ) {
                case MCSAssetExportStatusFinished:
                case MCSAssetExportStatusFailed:
                case MCSAssetExportStatusSuspended:
                    [mSqlite3 updateObjects:@[exporter] forKeys:@[@"status"] error:NULL];
                    break;
                case MCSAssetExportStatusUnknown:
                case MCSAssetExportStatusCancelled:
                case MCSAssetExportStatusWaiting:
                case MCSAssetExportStatusExporting:
                    break;
            }
        }
        
        NSArray<id<MCSAssetExportObserver>> *observers = MCSAllHashTableObjects(self->mObservers);
        dispatch_async(dispatch_get_main_queue(), ^{
            for ( id<MCSAssetExportObserver> observer in observers ) {
                if ( [observer respondsToSelector:@selector(exporter:statusDidChange:)] ) {
                    [observer exporter:exporter statusDidChange:status];
                }
            }
        });
    }
}

- (void)exporter:(id<MCSAssetExporter>)exporter didCompleteWithError:(nullable NSError *)error {
    @synchronized (self) {
        if ( error != nil ) {
            if ( error.domain == MCSErrorDomain && error.code == MCSCancelledError ) return; // return if cancelled;
            NSArray<id<MCSAssetExportObserver>> *observers = MCSAllHashTableObjects(self->mObservers);
            dispatch_async(dispatch_get_main_queue(), ^{
                for ( id<MCSAssetExportObserver> observer in observers ) {
                    if ( [observer respondsToSelector:@selector(exporter:statusDidChange:)] ) {
                        [observer exporter:exporter failedWithError:error];
                    }
                }
            });
        }
    }
}

- (void)exporter:(id<MCSAssetExporter>)exporter progressDidChange:(float)progress {
    @synchronized (self) {
        NSArray<id<MCSAssetExportObserver>> *observers = MCSAllHashTableObjects(self->mObservers);
        dispatch_async(dispatch_get_main_queue(), ^{
            for ( id<MCSAssetExportObserver> observer in observers ) {
                if ( [observer respondsToSelector:@selector(exporter:progressDidChange:)] ) {
                    [observer exporter:exporter progressDidChange:progress];
                }
            }
        });
    }
}

#pragma mark - unlocked

- (MCSAssetExporter *)_ensureExporterForURL:(NSURL *)URL {
    NSString *name = [MCSURL.shared assetNameForURL:URL];
    MCSAssetExporter *exporter = [self _queryExporterForName:name];
    if ( exporter == nil ) {
        MCSAssetType type = [MCSURL.shared assetTypeForURL:URL];
        exporter = [MCSAssetExporter.alloc initWithURLString:URL.absoluteString name:name type:type];
        [MCSCacheManager.shared setProtected:YES forCacheWithURL:URL];
        [mSqlite3 save:exporter error:NULL];
        mExporters[name] = exporter;
    }
    return exporter;
}

// memory + disk
- (nullable MCSAssetExporter *)_queryExporterForName:(NSString *)name {
    // memory
    MCSAssetExporter *exporter = mExporters[name];
    if ( exporter == nil ) {
        // disk
        exporter = [mSqlite3 objectsForClass:MCSAssetExporter.class conditions:@[
            [SJSQLite3Condition conditionWithColumn:@"name" value:name]
        ] orderBy:nil error:NULL].firstObject;
        // add into memory
        if ( exporter != nil ) {
            mExporters[name] = exporter;
        }
    }
    return exporter;
}

// memory + disk
- (nullable NSArray<MCSAssetExporter *> *)_queryExportersForMask:(MCSAssetExportStatusQueryMask)mask {
    // memory
    NSArray<MCSAssetExporter *> *_Nullable memo = [self _queryExportersInMemoryForMask:mask];
    // disk
    NSMutableArray<NSNumber *> *queryStatus = NSMutableArray.array;
    if ( mask & MCSAssetExportStatusQueryMaskUnknown ) {
        [queryStatus addObject:@(MCSAssetExportStatusUnknown)];
    }
    if ( mask & MCSAssetExportStatusQueryMaskWaiting ) {
        [queryStatus addObject:@(MCSAssetExportStatusWaiting)];
    }
    if ( mask & MCSAssetExportStatusQueryMaskExporting ) {
        [queryStatus addObject:@(MCSAssetExportStatusExporting)];
    }
    if ( mask & MCSAssetExportStatusQueryMaskFinished ) {
        [queryStatus addObject:@(MCSAssetExportStatusFinished)];
    }
    if ( mask & MCSAssetExportStatusQueryMaskFailed ) {
        [queryStatus addObject:@(MCSAssetExportStatusFailed)];
    }
    if ( mask & MCSAssetExportStatusQueryMaskSuspended ) {
        [queryStatus addObject:@(MCSAssetExportStatusSuspended)];
    }
    if ( mask & MCSAssetExportStatusQueryMaskCancelled ) {
        [queryStatus addObject:@(MCSAssetExportStatusCancelled)];
    }
    NSMutableArray<NSNumber *> *queryNotIn = [NSMutableArray arrayWithObject:@(0)];
    for ( MCSAssetExporter *exporter in memo ) {
        [queryNotIn addObject:@(exporter.id)];
    }
    NSArray<MCSAssetExporter *> *_Nullable disk = [mSqlite3 objectsForClass:MCSAssetExporter.class conditions:@[
        [SJSQLite3Condition conditionWithColumn:@"id" notIn:queryNotIn],
        [SJSQLite3Condition conditionWithColumn:@"status" in:queryStatus]
    ] orderBy:nil error:NULL];
    // add into memory
    if ( disk.count != 0 ) {
        [disk enumerateObjectsUsingBlock:^(MCSAssetExporter * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            mExporters[obj.name] = obj;
        }];
    }
    
    NSMutableArray<MCSAssetExporter *> *_Nullable m = nil;
    if ( memo.count != 0 || disk.count != 0 ) {
        m = NSMutableArray.array;
        if ( memo.count != 0 )
            [m addObjectsFromArray:memo];
        if ( disk.count != 0 )
            [m addObjectsFromArray:disk];
    }
    return m.copy;
}

- (nullable NSArray<MCSAssetExporter *> *)_queryExportersInMemoryForMask:(MCSAssetExportStatusQueryMask)mask {
    __block NSMutableArray<MCSAssetExporter *> *_Nullable m = nil;
    [mExporters enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, MCSAssetExporter * _Nonnull exporter, BOOL * _Nonnull stop) {
        if ( (mask & (1 << exporter.status)) != 0 ) {
            if ( m == nil ) m = NSMutableArray.array;
            [m addObject:exporter];
        }
    }];
    return m.copy;
}
@end
