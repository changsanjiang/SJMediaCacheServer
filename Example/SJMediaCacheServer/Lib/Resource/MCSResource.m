//
//  MCSResource.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResource.h"

@interface MCSResource ()<NSLocking>
@property (nonatomic) NSInteger id;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic) NSInteger readWriteCount;
@end

@implementation MCSResource

- (instancetype)init {
    self = [super init];
    if ( self ) {
        _semaphore = dispatch_semaphore_create(1);
    }
    return self;
}

- (MCSResourceType)type {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];
}

- (id<MCSResourceReader>)readerWithRequest:(NSURLRequest *)request {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];
}

- (id<MCSResourcePrefetcher>)prefetcherWithRequest:(NSURLRequest *)request {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];
}

#pragma mark -

@synthesize readWriteCount = _readWriteCount;
- (void)setReadWriteCount:(NSInteger)readWriteCount {
    [self lock];
    @try {
        if ( _readWriteCount != readWriteCount ) {
            _readWriteCount = readWriteCount;
        }
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSInteger)readWriteCount {
    [self lock];
    @try {
        return _readWriteCount;;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)readWrite_retain {
    self.readWriteCount += 1;
}

- (void)readWrite_release {
    self.readWriteCount -= 1;
}

#pragma mark -

- (void)lock {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
}

- (void)unlock {
    dispatch_semaphore_signal(_semaphore);
}
@end
