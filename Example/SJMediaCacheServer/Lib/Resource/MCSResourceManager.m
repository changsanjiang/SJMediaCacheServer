//
//  MCSResourceManager.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResourceManager.h"
#import "MCSResource.h"
#import "MCSResourceReader.h"
#import "MCSResource+MCSPrivate.h"
#import "MCSResourcePartialContent.h"
#import "MCSResourceFileManager.h"
#import <SJUIKit/SJSQLite3.h>
#import <SJUIKit/SJSQLite3+QueryExtended.h>

NSNotificationName const MCSResourceManagerWillRemoveResourceNotification = @"MCSResourceManagerWillRemoveResourceNotification";
NSString *MCSResourceManagerUserInfoResourceKey = @"resource";

@interface MCSResource (MCSResourceManagerExtended)<SJSQLiteTableModelProtocol>

@end

@implementation MCSResource (MCSResourceManagerExtended)
+ (NSString *)sql_primaryKey {
    return @"id";
}

+ (NSArray<NSString *> *)sql_autoincrementlist {
    return @[@"id"];
}

+ (NSArray<NSString *> *)sql_blacklist {
    return @[@"readWriteCount"];
}
@end

@interface SJSQLite3Condition (MCSResourceManagerExtended)
+ (instancetype)mcs_conditionWithColumn:(NSString *)column notIn:(NSArray *)values;
@end

@implementation SJSQLite3Condition (MCSResourceManagerExtended)
+ (instancetype)mcs_conditionWithColumn:(NSString *)column notIn:(NSArray *)values {
//    WHERE prod_price NOT IN (3.49, 5);
    NSMutableString *conds = NSMutableString.new;
    [conds appendFormat:@"\"%@\" NOT IN (", column];
    id last = values.lastObject;
    for ( id value in values ) {
        [conds appendFormat:@"'%@'%@", sj_sqlite3_obj_filter_obj_value(value), last!=value?@",":@""];
    }
    [conds appendString:@")"];
    return [[SJSQLite3Condition alloc] initWithCondition:conds];
}
@end


#pragma mark -

@interface MCSResourceManager ()<NSLocking> {
    NSRecursiveLock *_lock;
}
@property (nonatomic, strong) NSMutableDictionary<NSString *, MCSResource *> *resources;
@property (nonatomic, strong) SJSQLite3 *sqlite3;
@property (nonatomic) NSUInteger count;
@end

@implementation MCSResourceManager
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
        _sqlite3 = [SJSQLite3.alloc initWithDatabasePath:[MCSResourceFileManager databasePath]];
        _cacheCountLimit = 20;
        
        _lock = NSRecursiveLock.alloc.init;
        _resources = NSMutableDictionary.dictionary;

        _count = [_sqlite3 countOfObjectsForClass:MCSResource.class conditions:nil error:NULL];

        [self _removeEldestResourcesIfNeeded];
        
        self.maxDiskAgeForResource = 10 * 60;
    }
    return self;
}

- (MCSResource *)resourceWithURL:(NSURL *)URL {
    [self lock];
    @try {
        NSString *name = [MCSURLConvertor.shared resourceNameWithURL:URL];
        if ( _resources[name] == nil ) {
            // query
            MCSResource *resource = (id)[_sqlite3 objectsForClass:MCSResource.class conditions:@[
                [SJSQLite3Condition conditionWithColumn:@"name" value:name]
            ] orderBy:nil error:NULL].firstObject;
            
            // create
            if ( resource == nil ) {
                resource = [MCSResource.alloc initWithName:name];
                resource.createdTime = NSDate.date.timeIntervalSince1970;
                [_sqlite3 save:resource error:NULL];
                _count += 1;
            }
            
            // update
            resource.numberOfCumulativeUsage += 1;
            [self update:resource];
            
            // contents
            [resource addContents:[MCSResourceFileManager getContentsInResource:name]];
            _resources[name] = resource;
        }
        return _resources[name];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)update:(MCSResource *)resource {
    resource.updatedTime = NSDate.date.timeIntervalSince1970;
    if ( resource != nil ) [_sqlite3 save:resource error:NULL];
}

- (void)reader:(MCSResourceReader *)reader willReadResource:(MCSResource *)resource {

}

- (void)reader:(MCSResourceReader *)reader didEndReadResource:(MCSResource *)resource {
    [self lock];
    [self _removeEldestResourcesIfNeeded];
    [self unlock];
}

@synthesize maxDiskAgeForResource = _maxDiskAgeForResource;
- (void)setMaxDiskAgeForResource:(NSTimeInterval)maxDiskAgeForResource {
    @try {
        _maxDiskAgeForResource = maxDiskAgeForResource;
        if ( maxDiskAgeForResource != 0 ) {
            [self _removeExpiredResourcesIfNeeded];
        }
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSTimeInterval)maxDiskAgeForResource {
    @try {
        return _maxDiskAgeForResource;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)removeAllResources {
    [self lock];
    @try {
        [_resources removeAllObjects];
        NSArray<MCSResource *> *resources = [_sqlite3 objectsForClass:MCSResource.class conditions:nil orderBy:nil error:NULL];
        [self _removeResources:resources];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

/// 该方法只在初始化时调用
///
- (void)_removeExpiredResourcesIfNeeded {
    if ( _maxDiskAgeForResource == 0 ) return;;
    
    NSMutableArray<NSNumber *> *usingResources = NSMutableArray.alloc.init;
    [_resources enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, MCSResource * _Nonnull obj, BOOL * _Nonnull stop) {
        if ( obj.readWriteCount > 0 )
            [usingResources addObject:@(obj.id)];
    }];
    
    // 全部处于使用中
    if ( usingResources.count == _count )
        return;
 
    NSTimeInterval time = NSDate.date.timeIntervalSince1970 - _maxDiskAgeForResource;
    
    NSArray<MCSResource *> *results = [_sqlite3 objectsForClass:MCSResource.class conditions:@[
        [SJSQLite3Condition mcs_conditionWithColumn:@"id" notIn:usingResources],
        [SJSQLite3Condition conditionWithColumn:@"updatedTime" relatedBy:SJSQLite3RelationLessThanOrEqual value:@(time)],
    ] orderBy:@[
        [SJSQLite3ColumnOrder orderWithColumn:@"updatedTime" ascending:YES],
        [SJSQLite3ColumnOrder orderWithColumn:@"numberOfCumulativeUsage" ascending:YES],
    ] error:NULL];
    
    if ( results.count == 0 )
        return;
    
    // 删除
    [self _removeResources:results];
}

- (void)_removeEldestResourcesIfNeeded {
    if ( _cacheCountLimit == 0 ) return;
    
    // 资源数量少于限制的个数
    if ( _count < _cacheCountLimit )
        return;
    
    NSMutableArray<NSNumber *> *usingResources = NSMutableArray.alloc.init;
    [_resources enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, MCSResource * _Nonnull obj, BOOL * _Nonnull stop) {
        if ( obj.readWriteCount > 0 )
            [usingResources addObject:@(obj.id)];
    }];
    
    // 全部处于使用中
    if ( usingResources.count == _count )
        return;
    
    // 删除最近更新时间与最近使用次数最少的资源
    NSArray<MCSResource *> *results = [_sqlite3 objectsForClass:MCSResource.class conditions:@[
        [SJSQLite3Condition mcs_conditionWithColumn:@"id" notIn:usingResources]
    ] orderBy:@[
        [SJSQLite3ColumnOrder orderWithColumn:@"updatedTime" ascending:YES],
        [SJSQLite3ColumnOrder orderWithColumn:@"numberOfCumulativeUsage" ascending:YES],
    ] range:NSMakeRange(0, _count - _cacheCountLimit + 1) error:NULL];
    
    if ( results.count == 0 )
        return;
    
    // 删除
    [self _removeResources:results];
}

- (void)_removeResources:(NSArray<MCSResource *> *)resources {
    if ( resources.count == 0 )
        return;
    
    [resources enumerateObjectsUsingBlock:^(MCSResource * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [NSNotificationCenter.defaultCenter postNotificationName:MCSResourceManagerWillRemoveResourceNotification object:self userInfo:@{ MCSResourceManagerUserInfoResourceKey : obj }];
        NSString *path = [MCSResourceFileManager getResourcePathWithName:obj.name];
        [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
        [self.sqlite3 removeObjectForClass:MCSResource.class primaryKeyValue:@(obj.id) error:NULL];
        self.count -= 1;
    }];
}

#pragma mark -

- (void)lock {
    [_lock lock];
}

- (void)unlock {
    [_lock unlock];
}
@end
