//
//  MCSCacheManager.m
//  Pods-SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/3/26.
//

#import "MCSCacheManager.h"
#import "NSFileManager+MCS.h"
#import "MCSRootDirectory.h"
#import "MCSConsts.h"
#import "MCSUtils.h"
#import "MCSAssetManager.h"
#import "MCSDatabase.h"
#import "HLSAsset.h"

typedef NS_ENUM(NSUInteger, MCSLimit) {
    MCSLimitNone,
    MCSLimitCount,
    MCSLimitCacheDiskSpace,
    MCSLimitFreeDiskSpace,
    MCSLimitExpires,
};

/// 受保护的缓存项
@interface MCSProtectedCacheItem : NSObject<MCSSaveable>
- (instancetype)initWithAsset:(id<MCSAsset>)asset;
@property (nonatomic) NSInteger id;
@property (nonatomic) NSInteger asset;
@property (nonatomic) MCSAssetType assetType;
@end

@implementation MCSProtectedCacheItem
+ (NSString *)sql_primaryKey {
    return @"id";
}

+ (NSArray<NSString *> *)sql_autoincrementlist {
    return @[@"id"];
}

+ (NSString *)sql_tableName {
    return @"MCSAssetCacheTmpProtectedItem";
}

- (instancetype)initWithAsset:(id<MCSAsset>)asset {
    self = [super init];
    if ( self ) {
        _asset = asset.id;
        _assetType = asset.type;
    }
    return self;
}
@end

@interface MCSCacheManager () {
    unsigned long long _cacheSize;
    unsigned long long _freeSize;
    NSInteger _countOfProtectedAssets;
    SJSQLite3 *_sqlite3;
}

@end

@implementation MCSCacheManager
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
        _checkInterval = 30;
        _lastTimeLimit = 60;
        _sqlite3 = MCSDatabase();
        _countOfProtectedAssets = [_sqlite3 countOfObjectsForClass:MCSProtectedCacheItem.class conditions:nil error:NULL];
        [self _checkCachesRecursively];
        
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_fileWriteOutOfSpaceErrorWithNote:) name:MCSFileWriteOutOfSpaceErrorNotification object:nil];
    }
    return self;
}

#pragma mark -

- (UInt64)countOfBytesAllCaches {
    return MCSAssetManager.shared.countOfBytesAllAssets;
}

- (UInt64)countOfBytesUnprotectedCaches {
    @synchronized (self) {
        return [MCSAssetManager.shared countOfBytesNotIn:[self _allProtectedAssets]];
    }
}

- (BOOL)isProtectedForCacheWithURL:(NSURL *)URL {
    if ( URL == nil )
        return NO;
    return [self isProtectedForCacheWithAsset:[MCSAssetManager.shared assetWithURL:URL]];
}

- (BOOL)isProtectedForCacheWithAsset:(id<MCSAsset>)asset {
    @synchronized (self) {
        return [self _isProtectedForCacheWithAsset:asset];
    }
}

- (BOOL)removeCacheForURL:(NSURL *)URL {
    if ( URL == nil )
        return NO;
    return [self removeCacheForAsset:[MCSAssetManager.shared assetWithURL:URL]];
}

- (BOOL)removeCacheForAsset:(id<MCSAsset>)asset {
    BOOL isRemoved = NO;
    if ( asset != nil ) {
        @synchronized (self) {
            if ( ![self _isProtectedForCacheWithAsset:asset] ) {
                [MCSAssetManager.shared removeAsset:asset];
                isRemoved = YES;
            }
        }
    }
    return isRemoved;
}

- (void)removeUnprotectedCaches {
    @synchronized (self) {
        NSDictionary<MCSAssetTypeNumber *, NSArray<MCSAssetIDNumber *> *> *protectedAssets = [self _allProtectedAssets];
        [MCSAssetManager.shared removeAssetsNotIn:protectedAssets];
        _countOfProtectedAssets = protectedAssets.count;
    }
}

- (void)setProtected:(BOOL)isProtected forCacheWithURL:(NSURL *)URL {
    [self setProtected:isProtected forCacheWithAsset:[MCSAssetManager.shared assetWithURL:URL]];
}

- (void)setProtected:(BOOL)isProtected forCacheWithAsset:(id<MCSAsset>)asset {
    if ( asset != nil ) {
        @synchronized (self) {
            MCSProtectedCacheItem *item = (id)[_sqlite3 objectsForClass:MCSProtectedCacheItem.class conditions:@[
                [SJSQLite3Condition conditionWithColumn:@"assetType" value:@(asset.type)],
                [SJSQLite3Condition conditionWithColumn:@"asset" value:@(asset.id)]
            ] orderBy:nil error:NULL].firstObject;
            
            if ( isProtected ) {
                // save
                if ( item == nil ) {
                    _countOfProtectedAssets += 1;
                    item = [MCSProtectedCacheItem.alloc initWithAsset:asset];
                    [_sqlite3 save:item error:NULL];
                }
                
                // return
                return;
            }

            // delete
            if ( item != nil ) {
                _countOfProtectedAssets -= 1;
                [_sqlite3 removeObjectForClass:MCSProtectedCacheItem.class primaryKeyValue:@(item.id) error:NULL];
            }
        }
    }
}

#pragma mark - note

// 空间不足
- (void)_fileWriteOutOfSpaceErrorWithNote:(NSNotification *)note {
    @synchronized (self) {
        [self _trim];
    }
}

#pragma mark -

- (void)_checkCachesRecursively {
    if ( _checkInterval == 0 ) return;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_checkInterval * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        @synchronized (self) {
            [self _trim];
        }
        
        [self _checkCachesRecursively];
    });
}
 
- (void)_syncDiskSpace {
    _freeSize = [NSFileManager.defaultManager mcs_freeDiskSpace];
    _cacheSize = [MCSRootDirectory size];
}

- (void)_trim {
    [self _syncDiskSpace];
    [self _removeAssetsForLimit:MCSLimitFreeDiskSpace];
    [self _removeAssetsForLimit:MCSLimitCacheDiskSpace];
    [self _removeAssetsForLimit:MCSLimitExpires];
    [self _removeAssetsForLimit:MCSLimitCount];
}

- (BOOL)_isProtectedForCacheWithAsset:(id<MCSAsset>)asset {
    return [_sqlite3 objectsForClass:MCSProtectedCacheItem.class conditions:@[
        [SJSQLite3Condition conditionWithColumn:@"assetType" value:@(asset.type)],
        [SJSQLite3Condition conditionWithColumn:@"asset" value:@(asset.id)]
    ] orderBy:nil error:NULL].count != 0;
}
 
- (void)_removeAssetsForLimit:(MCSLimit)limit {
    NSInteger count = MCSAssetManager.shared.countOfAllAssets - _countOfProtectedAssets;

    switch ( limit ) {
        case MCSLimitNone:
            return;
        case MCSLimitCount: {
            if ( _cacheCountLimit == 0 )
                return;
            
            
            if ( count == 1 )
                return;
            
            // 资源数量少于限制的个数
            if ( _cacheCountLimit > count )
                return;
        }
            break;
        case MCSLimitFreeDiskSpace: {
            if ( _cacheReservedFreeDiskSpace == 0 )
                return;
            
            if ( _freeSize > _cacheReservedFreeDiskSpace )
                return;
        }
            break;
        case MCSLimitExpires: {
            if ( _cacheMaxDiskAge == 0 )
                return;
        }
            break;
        case MCSLimitCacheDiskSpace: {
            if ( _cacheMaxDiskSize == 0 )
                return;
            
            // 获取已缓存的数据大小
            if ( _cacheMaxDiskSize > _cacheSize )
                return;
        }
            break;
    }
    
    NSDictionary<MCSAssetTypeNumber *, NSArray<MCSAssetIDNumber *> *> *protectedAssets = [self _allProtectedAssets];
    switch ( limit ) {
        case MCSLimitNone:
            break;
        case MCSLimitCount:
        case MCSLimitCacheDiskSpace:
        case MCSLimitFreeDiskSpace: {
            // 清理`lastTimeLimit`之前的
            // 清理一半
            NSTimeInterval timeLimit = NSDate.date.timeIntervalSince1970 - _lastTimeLimit;
            NSInteger countLimit = (NSInteger)ceil(_cacheCountLimit != 0 ? (count - _cacheCountLimit * 0.5) : (count * 0.5));
            [MCSAssetManager.shared trimAssetsForLastReadingTime:timeLimit notIn:protectedAssets countLimit:countLimit];
        }
            break;
        case MCSLimitExpires: {
            NSTimeInterval timeLimit = NSDate.date.timeIntervalSince1970 - _cacheMaxDiskAge;
            [MCSAssetManager.shared trimAssetsForLastReadingTime:timeLimit notIn:protectedAssets];
        }
            break;
    }
}

#pragma mark - mark

- (NSDictionary<MCSAssetTypeNumber *, NSArray<MCSAssetIDNumber *> *> *)_allProtectedAssets {
    NSArray<NSDictionary *> *protectedHLSAssets = [_sqlite3 queryDataForClass:MCSProtectedCacheItem.class resultColumns:@[@"asset"] conditions:@[
        [SJSQLite3Condition conditionWithColumn:@"assetType" value:@(MCSAssetTypeHLS)]
    ] orderBy:nil error:NULL];
    NSArray<NSDictionary *> *protectedFILEAssets = [_sqlite3 queryDataForClass:MCSProtectedCacheItem.class resultColumns:@[@"asset"] conditions:@[
        [SJSQLite3Condition conditionWithColumn:@"assetType" value:@(MCSAssetTypeFILE)]
    ] orderBy:nil error:NULL];
    
    NSMutableDictionary<MCSAssetTypeNumber *, NSArray<MCSAssetIDNumber *> *> *protectedAssets = nil;
    if ( protectedHLSAssets.count != 0 || protectedFILEAssets.count != 0 ) {
        protectedAssets = NSMutableDictionary.dictionary;
    }
    
    if ( protectedHLSAssets.count != 0 ) {
        NSArray<NSNumber *> *masterAssets = SJFoundationExtendedValuesForKey(@"asset", protectedHLSAssets);
        NSMutableArray<NSNumber *> *array = masterAssets.mutableCopy;
        for ( NSNumber *assetId in masterAssets ) {
            HLSAsset *masterAsset = [MCSAssetManager.shared queryAssetForAssetId:assetId.integerValue type:MCSAssetTypeHLS];
            HLSAsset *_Nullable selectedVariantStreamAsset = masterAsset.selectedVariantStreamAsset;
            if ( selectedVariantStreamAsset  != nil ) {
                HLSAsset *_Nullable selectedAudioRenditionAsset = masterAsset.selectedAudioRenditionAsset;
                HLSAsset *_Nullable selectedVideoRenditionAsset = masterAsset.selectedVideoRenditionAsset;
                [array addObject:@(selectedVariantStreamAsset.id)];
                if ( selectedAudioRenditionAsset != nil ) [array addObject:@(selectedAudioRenditionAsset.id)];
                if ( selectedVideoRenditionAsset != nil ) [array addObject:@(selectedVideoRenditionAsset.id)];
            }
        }
        protectedAssets[@(MCSAssetTypeHLS)] = array.copy;
    }
    
    if ( protectedFILEAssets.count != 0 ) {
        protectedAssets[@(MCSAssetTypeFILE)] = SJFoundationExtendedValuesForKey(@"asset", protectedFILEAssets);
    }
    return protectedAssets.copy;
}

@end
