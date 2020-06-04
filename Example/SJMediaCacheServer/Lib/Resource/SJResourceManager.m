//
//  SJResourceManager.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceManager.h"
#import "SJResource.h"
#import "SJResourcePartialContent.h"
#import "SJResourceFileManager.h"
#import <SJUIKit/SJSQLite3.h>

@interface SJResource (Private)
- (instancetype)initWithName:(NSString *)name;
@end

#pragma mark -

@interface SJResource (SJResourceManagerExtended)

@end

@implementation SJResource (SJResourceManagerExtended)

@end

#pragma mark -

@interface SJResourceManager ()<NSLocking>
@property (nonatomic, strong) NSMutableDictionary<NSString *, SJResource *> *resources;
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
        _semaphore = dispatch_semaphore_create(1);
        _resources = NSMutableDictionary.dictionary;
        _convertor = SJURLConvertor.alloc.init;
    }
    return self;
}

- (SJResource *)resourceWithURL:(NSURL *)URL {
    [self lock];
    @try {
        NSString *name = [self.convertor resourceNameWithURL:URL];
        if ( self.resources[name] == nil ) {
            self.resources[name] = [SJResource.alloc initWithName:name];
        }
        return self.resources[name];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)save:(SJResource *)resource {
    
}

#pragma mark -

- (void)lock {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
}

- (void)unlock {
    dispatch_semaphore_signal(_semaphore);
}
@end
