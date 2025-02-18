//
//  MCSExporterManager.m
//  SJMediaCacheServer
//
//  Created by BD on 2021/3/10.
//

#import "MCSExporterManager.h"
#import "MCSExporter.h"
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

@interface MCSExporterManager ()<MCSExporterDelegate> {
    SJSQLite3 *mSqlite3;
    NSHashTable<id<MCSExportObserver>> *_Nullable mObservers;
    NSMutableDictionary<NSString *, MCSExporter *> *mExporters;
}
@end

@implementation MCSExporterManager
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

- (nullable NSArray<id<MCSExporter>> *)allExporters {
    NSArray<id<MCSExporter>> *allExporters = nil;
    @synchronized (self) {
        // memory
        NSMutableArray<NSNumber *> *memoryExporterIds = mExporters.count != 0 ? ([NSMutableArray arrayWithCapacity:mExporters.count]) : nil;
        [mExporters enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, MCSExporter * _Nonnull exporter, BOOL * _Nonnull stop) {
            [memoryExporterIds addObject:@(exporter.id)];
        }];
        
        // disk
        NSArray<SJSQLite3Condition *> *conditions = nil;
        if ( memoryExporterIds.count != 0 ) {
            conditions = @[[SJSQLite3Condition conditionWithColumn:@"id" notIn:memoryExporterIds]];
        }
        NSArray<MCSExporter *> *diskExporters = [mSqlite3 objectsForClass:MCSExporter.class conditions:conditions orderBy:nil error:NULL];
        if ( diskExporters.count != 0 ) {
            [diskExporters enumerateObjectsUsingBlock:^(MCSExporter * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
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
- (void)registerObserver:(id<MCSExportObserver>)observer {
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
- (void)removeObserver:(id<MCSExportObserver>)observer {
    if ( observer != nil ) {
        @synchronized (self) {
            [mObservers removeObject:observer];
        }
    }
}

/// 添加一个导出任务
///
/// \code
///         id<MCSExporter> exporter = [session exportAssetWithURL:URL];
///         // 开启
///         [exporter resume];
/// \endcode
///
- (nullable id<MCSExporter>)exportAssetWithURL:(NSURL *)URL {
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
            MCSExporter *_Nullable exporter = [self _queryExporterForName:name];
            if ( exporter != nil ) {
                [exporter cancel];
                mExporters[exporter.name] = nil;
                [mSqlite3 removeObjectForClass:MCSExporter.class primaryKeyValue:@(exporter.id) error:NULL];
                [MCSCacheManager.shared setProtected:NO forCacheWithURL:URL];
                [MCSCacheManager.shared removeCacheForURL:URL];
                
                for ( id<MCSExportObserver> observer in MCSAllHashTableObjects(mObservers) ) {
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
        for ( MCSExporter *exporter in mExporters ) {
            [memoryExporterIds addObject:@(exporter.id)];
        }
        
        NSArray<SJSQLite3Condition *> *conditions = nil;
        if ( memoryExporterIds.count != 0 ) {
            conditions = @[[SJSQLite3Condition conditionWithColumn:@"id" notIn:memoryExporterIds]];
        }
        NSArray<MCSExporter *> *disk = [mSqlite3 objectsForClass:MCSExporter.class conditions:conditions orderBy:nil error:NULL];
        NSArray<MCSExporter *> *memo = mExporters.allValues;
        
        NSMutableArray<MCSExporter *> *allExporters = [NSMutableArray arrayWithCapacity:disk.count + memo.count];
        if ( disk.count != 0 ) {
            [allExporters addObjectsFromArray:disk];
        }
        
        if ( memo.count != 0 ) {
            [allExporters addObjectsFromArray:memo];
        }
        
        if ( allExporters.count != 0 ) {
            for ( MCSExporter *exporter in allExporters ) {
                [exporter cancel];
                id<MCSAsset> asset = [MCSAssetManager.shared assetWithName:exporter.name type:exporter.type];
                [MCSCacheManager.shared setProtected:NO forCacheWithAsset:asset];
                [MCSCacheManager.shared removeCacheForAsset:asset];
            }
            [mExporters removeAllObjects];
            [mSqlite3 removeAllObjectsForClass:MCSExporter.class error:NULL];
            for ( id<MCSExportObserver> observer in MCSAllHashTableObjects(mObservers) ) {
                if ( [observer respondsToSelector:@selector(exporterManagerDidRemoveAllAssets:)] ) {
                    [observer exporterManagerDidRemoveAllAssets:self];
                }
            }
        }
    }
}

/// 查询状态
///
- (MCSExportStatus)statusForURL:(NSURL *)URL {
    @synchronized (self) {
        NSString *name = [MCSURL.shared assetNameForURL:URL];
        MCSExporter *exporter = [self _queryExporterForName:name];
        return exporter != nil ? exporter.status : MCSExportStatusUnknown;
    }
}

/// 查询进度
///
- (float)progressForURL:(NSURL *)URL {
    @synchronized (self) {
        NSString *name = [MCSURL.shared assetNameForURL:URL];
        MCSExporter *exporter = [self _queryExporterForName:name];
        return exporter != nil ? exporter.progress : 0;
    }
}


/// 同步缓存, 更新缓存进度
///
- (void)synchronizeProgressForExporterWithURL:(NSURL *)URL {
    if ( URL != nil ) {
        @synchronized (self) {
            NSString *name = [MCSURL.shared assetNameForURL:URL];
            MCSExporter *exporter = [self _queryExporterForName:name];
            [exporter synchronize];
        }
    }
}

- (void)synchronize {
    @synchronized (self) {
        [mExporters enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, MCSExporter * _Nonnull exporter, BOOL * _Nonnull stop) {
            [exporter synchronize];
        }];
    }
}

- (nullable NSArray<id<MCSExporter>> *)exportersForMask:(MCSExportStatusQueryMask)mask {
    @synchronized (self) {
        return [self _exportersForMask:mask];
    }
}

#pragma mark - MCSExporterDelegate

- (void)exporter:(MCSExporter *)exporter statusDidChange:(MCSExportStatus)status {
    @synchronized (self) {
        if ( status == MCSExportStatusCancelled ) {
            id<MCSAsset> asset = [MCSAssetManager.shared assetWithName:exporter.name type:exporter.type];
            [MCSCacheManager.shared setProtected:NO forCacheWithAsset:asset];
            [mSqlite3 removeObjectForClass:MCSExporter.class primaryKeyValue:@(exporter.id) error:NULL];
            mExporters[exporter.name] = nil;
        }
        else {
            /// 将状态同步数据库
            ///
            /// 状态处于 Waiting, Exporting 时不需要同步至数据库, 仅维护 exporter 在内存中的状态即可.
            /// 当再次启动App时, 状态将在 Suspended, Failed, Finished 之间.
            ///
            switch ( exporter.status ) {
                case MCSExportStatusFinished:
                case MCSExportStatusFailed:
                case MCSExportStatusSuspended:
                    [mSqlite3 updateObjects:@[exporter] forKeys:@[@"status"] error:NULL];
                    break;
                case MCSExportStatusUnknown:
                case MCSExportStatusCancelled:
                case MCSExportStatusWaiting:
                case MCSExportStatusExporting:
                    break;
            }
        }
        
        NSArray<id<MCSExportObserver>> *observers = MCSAllHashTableObjects(self->mObservers);
        dispatch_async(dispatch_get_main_queue(), ^{
            for ( id<MCSExportObserver> observer in observers ) {
                if ( [observer respondsToSelector:@selector(exporter:statusDidChange:)] ) {
                    [observer exporter:exporter statusDidChange:status];
                }
            }
        });
    }
}

- (void)exporter:(id<MCSExporter>)exporter didCompleteWithError:(nullable NSError *)error {
    @synchronized (self) {
        if ( error != nil ) {
            if ( error.domain == MCSErrorDomain && error.code == MCSCancelledError ) return; // return if cancelled;
            NSArray<id<MCSExportObserver>> *observers = MCSAllHashTableObjects(self->mObservers);
            dispatch_async(dispatch_get_main_queue(), ^{
                for ( id<MCSExportObserver> observer in observers ) {
                    if ( [observer respondsToSelector:@selector(exporter:statusDidChange:)] ) {
                        [observer exporter:exporter failedWithError:error];
                    }
                }
            });
        }
    }
}

- (void)exporter:(id<MCSExporter>)exporter progressDidChange:(float)progress {
    @synchronized (self) {
        NSArray<id<MCSExportObserver>> *observers = MCSAllHashTableObjects(self->mObservers);
        dispatch_async(dispatch_get_main_queue(), ^{
            for ( id<MCSExportObserver> observer in observers ) {
                if ( [observer respondsToSelector:@selector(exporter:progressDidChange:)] ) {
                    [observer exporter:exporter progressDidChange:progress];
                }
            }
        });
    }
}

#pragma mark - unlocked

- (MCSExporter *)_ensureExporterForURL:(NSURL *)URL {
    NSString *name = [MCSURL.shared assetNameForURL:URL];
    MCSExporter *exporter = [self _queryExporterForName:name];
    if ( exporter == nil ) {
        MCSAssetType type = [MCSURL.shared assetTypeForURL:URL];
        exporter = [MCSExporter.alloc initWithURLString:URL.absoluteString name:name type:type];
        exporter.delegate = self;
        [MCSCacheManager.shared setProtected:YES forCacheWithURL:URL];
        [mSqlite3 save:exporter error:NULL];
        mExporters[name] = exporter;
    }
    return exporter;
}

// memory + disk
- (nullable MCSExporter *)_queryExporterForName:(NSString *)name {
    // memory
    MCSExporter *exporter = mExporters[name];
    if ( exporter == nil ) {
        // disk
        exporter = [mSqlite3 objectsForClass:MCSExporter.class conditions:@[
            [SJSQLite3Condition conditionWithColumn:@"name" value:name]
        ] orderBy:nil error:NULL].firstObject;
        // add into memory
        if ( exporter != nil ) {
            exporter.delegate = self;
            mExporters[name] = exporter;
        }
    }
    return exporter;
}

// memory + disk
- (nullable NSArray<MCSExporter *> *)_exportersForMask:(MCSExportStatusQueryMask)mask {
    // memory
    NSArray<MCSExporter *> *_Nullable memo = [self _queryExportersInMemoryForMask:mask];
    // disk
    NSMutableArray<NSNumber *> *queryStatus = NSMutableArray.array;
    if ( mask & MCSExportStatusQueryMaskUnknown ) {
        [queryStatus addObject:@(MCSExportStatusUnknown)];
    }
    if ( mask & MCSExportStatusQueryMaskWaiting ) {
        [queryStatus addObject:@(MCSExportStatusWaiting)];
    }
    if ( mask & MCSExportStatusQueryMaskExporting ) {
        [queryStatus addObject:@(MCSExportStatusExporting)];
    }
    if ( mask & MCSExportStatusQueryMaskFinished ) {
        [queryStatus addObject:@(MCSExportStatusFinished)];
    }
    if ( mask & MCSExportStatusQueryMaskFailed ) {
        [queryStatus addObject:@(MCSExportStatusFailed)];
    }
    if ( mask & MCSExportStatusQueryMaskSuspended ) {
        [queryStatus addObject:@(MCSExportStatusSuspended)];
    }
    if ( mask & MCSExportStatusQueryMaskCancelled ) {
        [queryStatus addObject:@(MCSExportStatusCancelled)];
    }
    NSMutableArray<NSNumber *> *queryNotIn = [NSMutableArray arrayWithObject:@(0)];
    for ( MCSExporter *exporter in memo ) {
        [queryNotIn addObject:@(exporter.id)];
    }
    NSArray<MCSExporter *> *_Nullable disk = [mSqlite3 objectsForClass:MCSExporter.class conditions:@[
        [SJSQLite3Condition conditionWithColumn:@"id" notIn:queryNotIn],
        [SJSQLite3Condition conditionWithColumn:@"status" in:queryStatus]
    ] orderBy:nil error:NULL];
    // add into memory
    if ( disk.count != 0 ) {
        [disk enumerateObjectsUsingBlock:^(MCSExporter * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            mExporters[obj.name] = obj;
        }];
    }
    
    NSMutableArray<MCSExporter *> *_Nullable m = nil;
    if ( memo.count != 0 || disk.count != 0 ) {
        m = NSMutableArray.array;
        if ( memo.count != 0 )
            [m addObjectsFromArray:memo];
        if ( disk.count != 0 )
            [m addObjectsFromArray:disk];
    }
    return m.copy;
}

- (nullable NSArray<MCSExporter *> *)_queryExportersInMemoryForMask:(MCSExportStatusQueryMask)mask {
    __block NSMutableArray<MCSExporter *> *_Nullable m = nil;
    [mExporters enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, MCSExporter * _Nonnull exporter, BOOL * _Nonnull stop) {
        if ( (mask & (1 << exporter.status)) != 0 ) {
            if ( m == nil ) m = NSMutableArray.array;
            [m addObject:exporter];
        }
    }];
    return m.copy;
}
@end
