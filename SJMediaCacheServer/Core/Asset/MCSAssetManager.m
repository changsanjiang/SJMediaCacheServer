//
//  MCSAssetManager.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSAssetManager.h"
#import <objc/message.h>

#import "MCSDatabase.h"
#import "MCSUtils.h"
#import "MCSAssetUsageLog.h"
#import "NSFileManager+MCS.h"
 
#import "FILEAsset.h"
#import "HLSAsset.h"
#import "LocalFileAsset.h"

#import "MCSRootDirectory.h"
#import "MCSConsts.h"

#import "MCSError.h"
#import "MCSRequest.h"

@interface MCSAssetManager ()<MCSAssetReaderObserver, MCSAssetObserver> {
    NSUInteger mCountOfAllAssets;
    NSMutableDictionary<NSString *, id<MCSAsset> > *mAssets;
    NSMutableDictionary<NSString *, MCSAssetUsageLog *> *mUsageLogs;
    SJSQLite3 *mSqlite3;
}

@property (nonatomic, copy, nullable) HLSVariantStreamSelectionHandler variantStreamSelectionHandler;
@property (nonatomic, copy, nullable) HLSRenditionSelectionHandler renditionSelectionHandler;
@property (nonatomic, copy, nullable) HLSKeyDecryptionHandler keyDecryptionHandler;
@end

@implementation MCSAssetManager
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
        mSqlite3 = MCSDatabase();
        mCountOfAllAssets = [mSqlite3 countOfObjectsForClass:MCSAssetUsageLog.class conditions:nil error:NULL];
        mAssets = NSMutableDictionary.dictionary;
        mUsageLogs = NSMutableDictionary.dictionary;
        [self _syncUsageLogsRecursively];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_syncUsageLogs) name:UIApplicationWillTerminateNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark -

- (UInt64)countOfBytesAllAssets {
    @synchronized (self) {
        return MCSRootDirectory.size - MCSRootDirectory.databaseSize;
    }
}

- (NSInteger)countOfAllAssets {
    @synchronized (self) {
        return mCountOfAllAssets;
    }
}

- (UInt64)countOfBytesNotIn:(nullable NSDictionary<MCSAssetTypeNumber *, NSArray<MCSAssetIDNumber *> *> *)assets {
    @synchronized (self) {
        __block UInt64 size = 0;
        for ( NSString *name in [self _queryAssetNamesInTableForType:MCSAssetTypeFILE assetsNotIn:assets[@(MCSAssetTypeFILE)] ?: [NSArray arrayWithObject:@(0)]] ) {
            size += [NSFileManager.defaultManager mcs_directorySizeAtPath:[MCSRootDirectory assetPathForFilename:name]];
        }
        for ( NSString *name in [self _queryAssetNamesInTableForType:MCSAssetTypeHLS assetsNotIn:assets[@(MCSAssetTypeHLS)] ?: [NSArray arrayWithObject:@(0)]] ) {
            size += [NSFileManager.defaultManager mcs_directorySizeAtPath:[MCSRootDirectory assetPathForFilename:name]];
        }
        return size;
    }
}

- (UInt64)countOfBytesIn:(nullable NSDictionary<MCSAssetTypeNumber *, NSArray<MCSAssetIDNumber *> *> *)assets {
    @synchronized (self) {
        __block UInt64 size = 0;
        for ( NSString *name in [self _queryAssetNamesInTableForType:MCSAssetTypeFILE assetsIn:assets[@(MCSAssetTypeFILE)] ?: [NSArray arrayWithObject:@(0)]] ) {
            size += [NSFileManager.defaultManager mcs_directorySizeAtPath:[MCSRootDirectory assetPathForFilename:name]];
        }
        for ( NSString *name in [self _queryAssetNamesInTableForType:MCSAssetTypeHLS assetsIn:assets[@(MCSAssetTypeHLS)] ?: [NSArray arrayWithObject:@(0)]] ) {
            size += [NSFileManager.defaultManager mcs_directorySizeAtPath:[MCSRootDirectory assetPathForFilename:name]];
        }
        return size;
    }
}

/// 获取或创建 asset;
- (nullable __kindof id<MCSAsset> )assetWithURL:(NSURL *)URL {
    MCSAssetType type = [MCSURL.shared assetTypeForURL:URL];
    NSString *name = [MCSURL.shared assetNameForURL:URL];
    @synchronized (self) {
        return [self _ensureAssetWithName:name type:type];
    }
}

/// 获取或创建 asset;
- (nullable __kindof id<MCSAsset>)assetWithName:(NSString *)name type:(MCSAssetType)type {
    @synchronized (self) {
        return [self _ensureAssetWithName:name type:type];
    }
}

/// 从缓存(内存或本地)获取 asset;
- (nullable __kindof id<MCSAsset>)queryAssetForAssetId:(NSInteger)assetId type:(MCSAssetType)type {
    @synchronized (self) {
        return [self _queryAssetForAssetId:assetId type:type];
    }
}

/// 查询 asset 的数据是否已全部保存;
- (BOOL)isAssetStoredForURL:(NSURL *)URL {
    NSString *name = [MCSURL.shared assetNameForURL:URL];
    MCSAssetType type = [MCSURL.shared assetTypeForURL:URL];
    @synchronized (self) {
        return [self _queryAssetForName:name type:type].isStored;
    }
}
 
- (nullable id<MCSAssetReader>)readerWithRequest:(NSURLRequest *)proxyRequest networkTaskPriority:(float)networkTaskPriority delegate:(nullable id<MCSAssetReaderDelegate>)delegate {
    id<MCSAsset> asset = [self assetWithURL:proxyRequest.URL];
    id<MCSAssetReader> reader = [asset readerWithRequest:[MCSRequest.alloc initWithProxyRequest:proxyRequest] networkTaskPriority:networkTaskPriority readDataDecryptor:_readDataDecryptor delegate:delegate];
    return reader;
}

- (void)removeAssetForURL:(NSURL *)URL {
    if ( URL.absoluteString.length == 0 ) return;
    MCSAssetType type = [MCSURL.shared assetTypeForURL:URL];
    NSString *name = [MCSURL.shared assetNameForURL:URL];
    @synchronized (self) {
        id<MCSAsset> asset = [self _queryAssetForName:name type:type];
        if ( asset != nil ) [self _removeAssetsInArray:@[asset]];
    }
}

- (void)removeAsset:(id<MCSAsset>)asset {
    if ( asset != nil ) {
        @synchronized (self) {
            [self _removeAssetsInArray:@[asset]];
        }
    }
}

- (void)removeAssetsInArray:(NSArray<id<MCSAsset>> *)array {
    if ( array != nil && array.count != 0 ) {
        @synchronized (self) {
            [self _removeAssetsInArray:array];
        }
    }
}

- (void)removeAssetsNotIn:(nullable NSDictionary<MCSAssetTypeNumber *, NSArray<MCSAssetIDNumber *> *> *)assets {
    @synchronized (self) {
        NSArray<id<MCSAsset> > *results = [self _queryAssetsNotIn:assets];
        [self _removeAssetsInArray:results]; // 删除
    }
}

/// 清理asset; 读取中的资源不会被删除
///
- (void)trimAssetsForLastReadingTime:(NSTimeInterval)timeLimit notIn:(nullable NSDictionary<MCSAssetTypeNumber *, NSArray<MCSAssetIDNumber *> *> *)assets {
    [self trimAssetsForLastReadingTime:timeLimit notIn:assets countLimit:NSNotFound];
}

/// 清理asset; 读取中的资源不会被删除
///
- (void)trimAssetsForLastReadingTime:(NSTimeInterval)timeLimit notIn:(nullable NSDictionary<MCSAssetTypeNumber *, NSArray<MCSAssetIDNumber *> *> *)assets countLimit:(NSInteger)countLimit {
    @synchronized (self) {
        // 过滤被使用中的资源
        NSMutableSet<NSNumber *> *readwriteFileAssets = NSMutableSet.set;
        NSMutableSet<NSNumber *> *readwriteHLSAssets = NSMutableSet.set;
        [mAssets enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id<MCSAsset>  _Nonnull asset, BOOL * _Nonnull stop) {
            if ( asset.readwriteCount > 0 ) {
                NSMutableSet<NSNumber *> *set = (asset.type == MCSAssetTypeFILE ? readwriteFileAssets : readwriteHLSAssets);
                [set addObject:@(asset.id)];
            }
        }];
        
        // not in
        [assets enumerateKeysAndObjectsUsingBlock:^(MCSAssetTypeNumber * _Nonnull key, NSArray<MCSAssetIDNumber *> * _Nonnull obj, BOOL * _Nonnull stop) {
            NSMutableSet<NSNumber *> *set = (key.integerValue == MCSAssetTypeFILE ? readwriteFileAssets : readwriteHLSAssets);
            [set addObjectsFromArray:obj];
        }];
        
        // 全部处于使用中
        NSInteger count = readwriteFileAssets.count + readwriteHLSAssets.count;
        if ( count == mCountOfAllAssets )
            return;
        
        [self _syncUsageLogs];
        
        [readwriteFileAssets addObject:@(0)];
        [readwriteHLSAssets addObject:@(0)];
        
        NSString *s0 = [readwriteFileAssets.allObjects componentsJoinedByString:@","];
        NSString *s1 = [readwriteHLSAssets.allObjects componentsJoinedByString:@","];
        
        NSArray<SJSQLite3RowData *> *rows = nil;
        if ( countLimit != NSNotFound ) {
            rows = [mSqlite3 exec:[NSString stringWithFormat:
                                   @"SELECT * FROM MCSAssetUsageLog WHERE ( (asset NOT IN (%@) AND assetType = 0) OR (asset NOT IN (%@) AND assetType = 1) ) \
                                                                      AND updatedTime <= %lf \
                                                                 ORDER BY updatedTime ASC \
                                                                    LIMIT 0, %ld;", s0, s1, timeLimit, (long)countLimit] error:NULL];
        }
        else {
            rows = [mSqlite3 exec:[NSString stringWithFormat:
                            @"SELECT * FROM MCSAssetUsageLog WHERE ( (asset NOT IN (%@) AND assetType = 0) OR (asset NOT IN (%@) AND assetType = 1) ) \
                                                               AND updatedTime <= %lf;", s0, s1, timeLimit] error:NULL];
        }
        NSArray<MCSAssetUsageLog *> *logs = [mSqlite3 objectsForClass:MCSAssetUsageLog.class rowDatas:rows error:NULL];
        if ( logs.count == 0 )
            return;
        
        // 删除
        NSMutableArray<id<MCSAsset> > *results = NSMutableArray.array;
        [logs enumerateObjectsUsingBlock:^(MCSAssetUsageLog * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            id<MCSAsset> asset = [self _queryAssetForAssetId:obj.asset type:obj.assetType];
            if ( asset != nil ) [results addObject:asset];
        }];

        [self _removeAssetsInArray:results];
    }
}

#pragma mark - MCSAssetObserver

- (void)assetDidLoadMetadata:(id<MCSAsset>)asset {
    @synchronized (self) {
        [self _syncToDatabase:asset];
    }
}

- (void)assetDidRead:(id<MCSAsset>)asset {
    @synchronized (self) {
        [mUsageLogs[asset.name] updateLastReadTime:NSDate.date.timeIntervalSince1970];
    }
}
 
#pragma mark - mark

- (void)_syncUsageLogsRecursively {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        @synchronized (self) {
            [self _syncUsageLogs];
        }
        [self _syncUsageLogsRecursively];
    });
}

#pragma mark - unlocked

/// 获取或创建 asset;
///
/// unlocked
- (nullable __kindof id<MCSAsset> )_ensureAssetWithName:(NSString *)name type:(MCSAssetType)type {
    return [self _queryAssetForName:name type:type] ?: [self _createAssetWithName:name type:type];
}

/// 创建 asset 并存入本地;
///
/// unlocked
- (nullable __kindof id<MCSAsset> )_createAssetWithName:(NSString *)name type:(MCSAssetType)type {
    id<MCSAsset> asset = nil;
    Class cls = [self _assetClassForType:type];
    asset = [cls.alloc initWithName:name]; // create asset
    [self _syncToDatabase:asset]; // save asset
    mCountOfAllAssets += 1;
    [asset prepare];
    [asset registerObserver:self];
    mAssets[name] = asset;

    MCSAssetUsageLog *log = [MCSAssetUsageLog.alloc initWithAsset:asset]; // create log
    [self _syncToDatabase:log]; // save log
    mUsageLogs[name] = log;
    
    if ( type == MCSAssetTypeHLS ) {
        HLSAsset *hls = (HLSAsset *)asset;
        __weak typeof(self) _self = self;
        hls.variantStreamSelectionHandler = ^id<HLSVariantStream> _Nullable(NSArray<id<HLSVariantStream>> * _Nonnull variantStreams, NSURL * _Nonnull originalURL, NSURL * _Nonnull currentURL) {
            __strong typeof(_self) self = _self;
            if ( self == nil ) return nil;
            return self.variantStreamSelectionHandler != nil ? self.variantStreamSelectionHandler(variantStreams, originalURL, currentURL) : nil;
        };
        hls.renditionSelectionHandler = ^id<HLSRendition> _Nullable(HLSRenditionType renditionType, id<HLSRenditionGroup>  _Nonnull renditionGroup, NSURL * _Nonnull originalURL, NSURL * _Nonnull currentURL) {
            __strong typeof(_self) self = _self;
            if ( self == nil ) return nil;
            return self.renditionSelectionHandler != nil ? self.renditionSelectionHandler(renditionType, renditionGroup, originalURL, currentURL) : nil;
        };
        hls.keyDecryptionHandler = ^NSData * _Nonnull(NSData * _Nonnull data, NSURL * _Nonnull originalURL, NSURL * _Nonnull currentURL) {
            __strong typeof(_self) self = _self;
            if ( self == nil ) return data;
            return self.keyDecryptionHandler != nil ? self.keyDecryptionHandler(data, originalURL, currentURL) : data;
        };
    }
    return asset;
}

/// 从缓存(内存或本地)获取 asset;
///
/// unlocked
- (nullable __kindof id<MCSAsset>)_queryAssetForName:(NSString *)name type:(MCSAssetType)type {
    id<MCSAsset> asset = mAssets[name];
    if ( asset == nil ) {
        asset = [self _queryAssetInTableForType:type conditions:@[
            [SJSQLite3Condition conditionWithColumn:@"name" value:name]
        ]];
    }
    return asset;
}

/// 从缓存(内存或本地)获取 asset;
///
/// unlocked
- (nullable __kindof id<MCSAsset>)_queryAssetForAssetId:(NSInteger)assetId type:(MCSAssetType)type {
    __block id<MCSAsset> asset = nil;
    [mAssets enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id<MCSAsset>  _Nonnull obj, BOOL * _Nonnull stop) {
        if ( obj.type == type && obj.id == assetId ) {
            asset = obj;
            *stop = YES;
        }
    }];
    
    if ( asset == nil ) {
        asset = [self _queryAssetInTableForType:type conditions:@[
            [SJSQLite3Condition conditionWithColumn:@"id" value:@(assetId)]
        ]];
    }
    return asset;
}

/// 从本地获取 asset;
///
/// unlocked
- (nullable __kindof id<MCSAsset>)_queryAssetInTableForType:(MCSAssetType)type conditions:(NSArray<SJSQLite3Condition *> *)conditions {
    Class cls = [self _assetClassForType:type];
    if ( cls == nil )
        return nil;
    __block id<MCSAsset> asset = (id)[mSqlite3 objectsForClass:cls conditions:conditions orderBy:nil error:NULL].firstObject;
    
    if ( asset != nil ) {
        [asset prepare];
        [asset registerObserver:self];
        mAssets[asset.name] = asset;
        
        MCSAssetUsageLog *log = [mSqlite3 objectsForClass:MCSAssetUsageLog.class conditions:@[
            [SJSQLite3Condition conditionWithColumn:@"asset" value:@(asset.id)],
            [SJSQLite3Condition conditionWithColumn:@"assetType" value:@(type)],
        ] orderBy:nil error:NULL].firstObject;
        mUsageLogs[asset.name] = log;
    }
    return asset;
}

/// 从本地获取 asset;
///
/// unlocked
- (nullable NSArray<id<MCSAsset>> *)_queryAssetsNotIn:(nullable NSDictionary<MCSAssetTypeNumber *, NSArray<MCSAssetIDNumber *> *> *)assets {
    
    NSMutableSet<NSNumber *> *FILEAssets = NSMutableSet.set;
    NSMutableSet<NSNumber *> *HLSAssets = NSMutableSet.set;
    // not in
    [assets enumerateKeysAndObjectsUsingBlock:^(MCSAssetTypeNumber * _Nonnull key, NSArray<MCSAssetIDNumber *> * _Nonnull obj, BOOL * _Nonnull stop) {
        NSMutableSet<NSNumber *> *set = (key.integerValue == MCSAssetTypeFILE ? FILEAssets : HLSAssets);
        [set addObjectsFromArray:obj];
    }];
    
    [FILEAssets addObject:@(0)];
    [HLSAssets addObject:@(0)];
    
    NSString *s0 = [FILEAssets.allObjects componentsJoinedByString:@","];
    NSString *s1 = [HLSAssets.allObjects componentsJoinedByString:@","];
    
    NSArray<SJSQLite3RowData *> *rows = [mSqlite3 exec:[NSString stringWithFormat:
                                                        @"SELECT * FROM MCSAssetUsageLog WHERE (asset NOT IN (%@) AND assetType = 0) \
                                                                                            OR (asset NOT IN (%@) AND assetType = 1);", s0, s1] error:NULL];
    NSArray<MCSAssetUsageLog *> *logs = [mSqlite3 objectsForClass:MCSAssetUsageLog.class rowDatas:rows error:NULL];
    if ( logs.count == 0 )
        return nil;
    
    NSMutableArray<id<MCSAsset> > *results = NSMutableArray.array;
    [logs enumerateObjectsUsingBlock:^(MCSAssetUsageLog * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        id<MCSAsset> asset = [self _queryAssetForAssetId:obj.asset type:obj.assetType];
        if ( asset != nil ) [results addObject:asset];
    }];
    return results;
}

- (nullable NSArray<NSString *> *)_queryAssetNamesInTableForType:(MCSAssetType)type assetsIn:(NSArray<MCSAssetIDNumber *> *)assetIds {
    NSString *assetTableName;
    switch (type) {
        case MCSAssetTypeFILE:
            assetTableName = @"FILEAsset";
            break;
        case MCSAssetTypeHLS:
            assetTableName = @"HLSAsset";
            break;
        case MCSAssetTypeLocalFile:
            assetTableName = @"LocalFileAsset";
            break;
    }
    NSArray<SJSQLite3RowData *> *values = [mSqlite3 exec:[NSString stringWithFormat:@"SELECT name FROM %@ INNER JOIN MCSAssetUsageLog ON (MCSAssetUsageLog.assetType = %ld AND MCSAssetUsageLog.asset IN (%@)) WHERE MCSAssetUsageLog.asset = %@.id;", assetTableName, type, assetIds, assetTableName] error:NULL];
    return SJFoundationExtendedValuesForKey(@"name", values);
}

- (nullable NSArray<NSString *> *)_queryAssetNamesInTableForType:(MCSAssetType)type assetsNotIn:(NSArray<MCSAssetIDNumber *> *)assetIds {
    NSString *assetTableName;
    switch (type) {
        case MCSAssetTypeFILE:
            assetTableName = @"FILEAsset";
            break;
        case MCSAssetTypeHLS:
            assetTableName = @"HLSAsset";
            break;
        case MCSAssetTypeLocalFile:
            assetTableName = @"LocalFileAsset";
            break;
    }
    NSArray<SJSQLite3RowData *> *values = [mSqlite3 exec:[NSString stringWithFormat:@"SELECT name FROM %@ INNER JOIN MCSAssetUsageLog ON (MCSAssetUsageLog.assetType = %ld AND MCSAssetUsageLog.asset NOT IN (%@)) WHERE MCSAssetUsageLog.asset = %@.id;", assetTableName, type, assetIds, assetTableName] error:NULL];
    return SJFoundationExtendedValuesForKey(@"name", values);
}

/// 删除 assets;
///
/// unlocked
- (void)_removeAssetsInArray:(NSArray<id<MCSAsset> > *)assets {
    if ( assets == nil || assets.count == 0 ) return;
    assets = assets.copy;
    [assets enumerateObjectsUsingBlock:^(id<MCSAsset>  _Nonnull r, NSUInteger idx, BOOL * _Nonnull stop) {
        [r clear];
        [mSqlite3 removeObjectForClass:r.class primaryKeyValue:@(r.id) error:NULL];
        [mSqlite3 removeAllObjectsForClass:MCSAssetUsageLog.class conditions:@[
            [SJSQLite3Condition conditionWithColumn:@"asset" value:@(r.id)],
            [SJSQLite3Condition conditionWithColumn:@"assetType" value:@(r.type)],
        ] error:NULL];
        [mAssets removeObjectForKey:r.name];
        [mUsageLogs removeObjectForKey:r.name];
    }];
    
    mCountOfAllAssets -= assets.count;
}

/// 同步到本地
///
/// unlocked
- (void)_syncToDatabase:(id<MCSSaveable>)saveable {
    if ( saveable != nil ) [mSqlite3 save:saveable error:NULL];
}

/// 同步到本地
///
/// unlocked
- (void)_syncUsageLogs {
    if ( mUsageLogs.count != 0 ) {
        __block NSMutableArray<MCSAssetUsageLog *> *changes = nil;
        [mUsageLogs enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, MCSAssetUsageLog * _Nonnull obj, BOOL * _Nonnull stop) {
            if ( obj.isUpdated ) {
                if ( changes == nil ) changes = NSMutableArray.array;
                [changes addObject:obj];
            }
        }];
        if ( changes != nil ) {
            [mSqlite3 updateObjects:changes forKeys:@[@"updatedTime"] error:NULL];
            [changes makeObjectsPerformSelector:@selector(completeSync)];
        }
    }
}
 
- (Class)_assetClassForType:(MCSAssetType)type {
    switch (type) {
        case MCSAssetTypeFILE:
            return FILEAsset.class;
        case MCSAssetTypeHLS:
            return HLSAsset.class;
        case MCSAssetTypeLocalFile:
            return LocalFileAsset.class;
    }
}
@end
