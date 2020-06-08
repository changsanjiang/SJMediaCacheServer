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
        _convertor = MCSURLConvertor.alloc.init;
        _cacheCountLimit = 20;
        
        _lock = NSRecursiveLock.alloc.init;
        _resources = NSMutableDictionary.dictionary;

        [self removeEldestResourcesIfNeeded];
    }
    return self;
}

- (MCSResource *)resourceWithURL:(NSURL *)URL {
    [self lock];
    @try {
        NSString *name = [_convertor resourceNameWithURL:URL];
        if ( _resources[name] == nil ) {
            MCSResource *resource = (id)[_sqlite3 objectsForClass:MCSResource.class conditions:@[
                [SJSQLite3Condition conditionWithColumn:@"name" value:name]
            ] orderBy:nil error:NULL].firstObject;
            if ( resource == nil ) {
                resource = [MCSResource.alloc initWithName:name];
                [_sqlite3 save:resource error:NULL];
            }
            [resource addContents:[MCSResourceFileManager getContentsInResource:name]];
            _resources[name] = resource;
        }
        
        // 更新使用次数
        _resources[name].numberOfCumulativeUsage += 1;
        [self update:_resources[name]];
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
    [self removeEldestResourcesIfNeeded];
}

- (void)removeEldestResourcesIfNeeded {
    [self lock];
    @try {
        if ( _cacheCountLimit == 0 ) return;
        
        NSUInteger count = [_sqlite3 countOfObjectsForClass:MCSResource.class conditions:nil error:NULL];
        // 资源数量少于限制的个数
        if ( count < _cacheCountLimit )
            return;
        
        NSMutableArray<NSNumber *> *using = NSMutableArray.alloc.init;
        [_resources enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, MCSResource * _Nonnull obj, BOOL * _Nonnull stop) {
            if ( obj.readWriteCount > 0 )
                [using addObject:@(obj.id)];
        }];
        
        // 全部处于使用中
        if ( using.count == count )
            return;
        
        // 删除最近更新时间与最近使用次数最少的资源
        NSArray<MCSResource *> *results = [_sqlite3 objectsForClass:MCSResource.class conditions:@[
            [SJSQLite3Condition mcs_conditionWithColumn:@"id" notIn:using]
        ] orderBy:@[
            [SJSQLite3ColumnOrder orderWithColumn:@"updatedTime" ascending:YES],
            [SJSQLite3ColumnOrder orderWithColumn:@"numberOfCumulativeUsage" ascending:YES],
        ] range:NSMakeRange(0, count - _cacheCountLimit + 1) error:NULL];

        if ( results.count == 0 )
            return;
        
        // 删除
        [self _removeResources:results];
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

- (void)_removeResources:(NSArray<MCSResource *> *)resources {
    if ( resources.count == 0 )
        return;
    
    [resources enumerateObjectsUsingBlock:^(MCSResource * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [NSNotificationCenter.defaultCenter postNotificationName:MCSResourceManagerWillRemoveResourceNotification object:self userInfo:@{ MCSResourceManagerUserInfoResourceKey : obj }];
        NSString *path = [MCSResourceFileManager getResourcePathWithName:obj.name];
        [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
        [self.sqlite3 removeObjectForClass:MCSResource.class primaryKeyValue:@(obj.id) error:NULL];
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
