//
//  MCSResourceManager.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResourceManager.h"
#import "MCSResource.h"
#import "MCSResource+MCSPrivate.h"
#import "MCSResourcePartialContent.h"
#import "MCSResourceFileManager.h"
#import <SJUIKit/SJSQLite3.h>
#import <SJUIKit/SJSQLite3+QueryExtended.h>

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

#pragma mark -

@interface MCSResourceManager ()<NSLocking>
@property (nonatomic, strong) NSMutableDictionary<NSString *, MCSResource *> *resources;
@property (nonatomic, strong) SJSQLite3 *sqlite3;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
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
        
        _semaphore = dispatch_semaphore_create(1);
        _resources = NSMutableDictionary.dictionary;
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
        return _resources[name];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)update:(MCSResource *)resource {
    [_sqlite3 save:resource error:NULL];
}

#pragma mark -

- (void)lock {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
}

- (void)unlock {
    dispatch_semaphore_signal(_semaphore);
}
@end

/*
 
 最近最少使用, 并且当前未被使用
 
 */
