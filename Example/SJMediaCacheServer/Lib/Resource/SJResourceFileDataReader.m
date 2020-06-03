//
//  SJResourceFileDataReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceFileDataReader.h"
#import "SJError.h"

@interface SJResourceFileDataReader()<NSLocking>
@property (nonatomic, strong) dispatch_queue_t delegateQueue;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, weak) id<SJResourceDataReaderDelegate> delegate;
@property (nonatomic) NSRange readRange;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSFileHandle *reader;

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isClosed;
@end

@implementation SJResourceFileDataReader
- (instancetype)initWithPath:(NSString *)path readRange:(NSRange)range {
    self = [super init];
    if ( self ) {
        _path = path.copy;
        _readRange = range;
        _semaphore = dispatch_semaphore_create(1);
        _delegateQueue = dispatch_get_global_queue(0, 0);
    }
    return self;
}

- (void)setDelegate:(id<SJResourceDataReaderDelegate>)delegate delegateQueue:(nonnull dispatch_queue_t)queue {
    [self lock];
    self.delegate = delegate;
    self.delegateQueue = queue;
    [self unlock];
}

- (void)prepare {
    [self lock];
    @try {
        if ( self.isClosed || self.isCalledPrepare )
            return;
        
        self.isCalledPrepare = YES;
        self.reader = [NSFileHandle fileHandleForReadingAtPath:self.path];
        [self.reader seekToFileOffset:self.readRange.location];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSUInteger)offset {
    [self lock];
    @try {
        return (NSUInteger)self.reader.offsetInFile - self.readRange.location;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (BOOL)isDone {
    [self lock];
    @try {
        return self.reader.offsetInFile - self.readRange.location == self.readRange.length;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (nullable NSData *)readDataOfLength:(NSUInteger)length {
    [self lock];
    @try {
        if ( self.isClosed )
            return nil;
        
        return [self.reader readDataOfLength:length];
    } @catch (NSException *exception) {
        [self callbackWithBlock:^{
            [self.delegate reader:self anErrorOccurred:[SJError errorForException:exception]];
        }];
    } @finally {
        [self unlock];
    }
}

- (void)close {
    [self lock];
    @try {
        if ( self.isClosed )
            return;
        
        self.isClosed = YES;
        [self.reader closeFile];
        self.reader = nil;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

#pragma mark -

- (void)lock {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
}

- (void)unlock {
    dispatch_semaphore_signal(_semaphore);
}

- (void)callbackWithBlock:(void(^)(void))block {
    dispatch_async(_delegateQueue, ^{
        if ( block ) block();
    });
}
@end
