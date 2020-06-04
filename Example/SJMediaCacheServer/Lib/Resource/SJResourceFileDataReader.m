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
@property (nonatomic) NSRange range;
@property (nonatomic) NSRange readRange;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSFileHandle *reader;

@property (nonatomic) NSUInteger offset;

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isClosed;
@end

@implementation SJResourceFileDataReader
- (instancetype)initWithRange:(NSRange)range path:(NSString *)path readRange:(NSRange)readRange {
    self = [super init];
    if ( self ) {
        _path = path.copy;
        _range = range;
        _readRange = readRange;
        _semaphore = dispatch_semaphore_create(1);
        _delegateQueue = dispatch_get_global_queue(0, 0);
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"SJResourceFileDataReader:<%p> { range: %@\n };", self, NSStringFromRange(_range)];
}

- (void)setDelegate:(id<SJResourceDataReaderDelegate>)delegate delegateQueue:(nonnull dispatch_queue_t)queue {
    [self lock];
    _delegate = delegate;
    _delegateQueue = queue;
    [self unlock];
}

- (void)prepare {
    [self lock];
    @try {
        if ( _isClosed || _isCalledPrepare )
            return;
        
#ifdef DEBUG
        printf("SJResourceFileDataReader: <%p>.prepare { range: %s };\n", self, NSStringFromRange(_range).UTF8String);
#endif
        _isCalledPrepare = YES;
        _reader = [NSFileHandle fileHandleForReadingAtPath:_path];
        [_reader seekToFileOffset:_readRange.location];
        
        [self callbackWithBlock:^{
            [self.delegate readerPrepareDidFinish:self];
        }];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSUInteger)offset {
    [self lock];
    @try {
        return _offset;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (BOOL)isDone {
    [self lock];
    @try {
        return _offset == _readRange.length;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (nullable NSData *)readDataOfLength:(NSUInteger)lengthParam {
    [self lock];
    @try {
        if ( _isClosed )
            return nil;
        
        NSUInteger length = MIN(lengthParam, _readRange.length - _offset);
        NSData *data = [_reader readDataOfLength:length];
        _offset += data.length;
        
#ifdef DEBUG
        if ( _offset == _readRange.length ) {
            printf("SJResourceFileDataReader: <%p>.isDone;\n", self);
        }
#endif
        return data;
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
        if ( _isClosed )
            return;
        
        _isClosed = YES;
        [_reader closeFile];
        _reader = nil;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
    
#ifdef DEBUG
    printf("SJResourceFileDataReader: <%p>.close;\n", self);
#endif
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
