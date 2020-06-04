//
//  SJResourceManager.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceManager.h"
#import "SJResource.h"
#import "SJResource+SJPrivate.h"
#import "SJResourcePartialContent.h"
#import "SJResourceFileManager.h"
#import <SJUIKit/SJSQLite3.h>
#import <SJUIKit/SJSQLite3+QueryExtended.h>

@interface SJResource (Private)
- (instancetype)initWithName:(NSString *)name;
@end

#pragma mark -

@interface SJResource (SJResourceManagerExtended)<SJSQLiteTableModelProtocol>

@end

@implementation SJResource (SJResourceManagerExtended)
+ (NSString *)sql_primaryKey {
    return @"id";
}

+ (NSArray<NSString *> *)sql_autoincrementlist {
    return @[@"id"];
}
@end

#pragma mark -

@interface SJResourceManager ()<NSLocking>
@property (nonatomic, strong) NSMutableDictionary<NSString *, SJResource *> *resources;
@property (nonatomic, strong) SJSQLite3 *sqlite3;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@end

@implementation SJResourceManager
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
        _sqlite3 = [SJSQLite3.alloc initWithDatabasePath:[SJResourceFileManager databasePath]];
        _convertor = SJURLConvertor.alloc.init;
        
        _semaphore = dispatch_semaphore_create(1);
        _resources = NSMutableDictionary.dictionary;
    }
    return self;
}

- (SJResource *)resourceWithURL:(NSURL *)URL {
    [self lock];
    @try {
        NSString *name = [_convertor resourceNameWithURL:URL];
        if ( _resources[name] == nil ) {
            SJResource *resource = (id)[_sqlite3 objectsForClass:SJResource.class conditions:@[
                [SJSQLite3Condition conditionWithColumn:@"name" value:name]
            ] orderBy:nil error:NULL].firstObject;
            if ( resource == nil ) {
                resource = [SJResource.alloc initWithName:name];
                [_sqlite3 save:resource error:NULL];
            }
            [resource addContents:[SJResourceFileManager getContentsInResource:name]];
            _resources[name] = resource;
        }
        return _resources[name];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)update:(SJResource *)resource {
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
