//
//  SJResourceReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceReader.h"

@interface SJResourceReader ()<NSLocking, SJDataReaderDelegate>
@property (nonatomic, strong) dispatch_queue_t delegateQueue;
@property (nonatomic) NSRange range;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, copy) NSArray<id<SJDataReader>> *readers;
@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isClosed;

@property (nonatomic) NSInteger currentIndex;
@property (nonatomic, strong) id<SJDataReader> currentReader;
@property (nonatomic) UInt64 offset;
@end

@implementation SJResourceReader
- (instancetype)initWithRange:(NSRange)range readers:(NSArray<id<SJDataReader>> *)readers {
    self = [super init];
    if ( self ) {
        _delegateQueue = dispatch_get_global_queue(0, 0);
        _semaphore = dispatch_semaphore_create(1);
        _range = range;
        _readers = readers.copy;
        _currentIndex = NSNotFound;
    }
    return self;
}

- (void)prepare {
    [self lock];
    @try {
        if ( self.isClosed || self.isCalledPrepare )
            return;
        
        self.isCalledPrepare = YES;
        [self prepareNextReader];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (UInt64)contentLength {
    return self.range.length;
}
 
- (NSData *)readDataOfLength:(NSUInteger)length {
    [self lock];
    @try {
        if ( self.isClosed || self.currentIndex == NSNotFound )
            return nil;
        
        NSData *data = [self.currentReader readDataOfLength:length];
        self.offset += data.length;
        if ( self.currentReader.isDone )
            [self prepareNextReader];
        return data;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (BOOL)isReadingEndOfData {
    [self lock];
    @try {
        return self.readers.lastObject.isDone;
    } @catch (__unused NSException *exception) {
        
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
        for ( id<SJDataReader> reader in self.readers ) {
            [reader close];
        }
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

#pragma mark -

- (void)prepareNextReader {
    self.currentIndex += 1;
    [self.currentReader setDelegate:self delegateQueue:self.delegateQueue];
    [self.currentReader prepare];
}

- (id<SJDataReader>)currentReader {
    return self.readers[_currentIndex];
}

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

- (void)readerPrepareDidFinish:(id<SJDataReader>)reader {
    [self callbackWithBlock:^{
        [self.delegate readerPrepareDidFinish:self];
    }];
}

- (void)readerHasAvailableData:(id<SJDataReader>)reader {
    [self callbackWithBlock:^{
        [self.delegate readerHasAvailableData:self];
    }];
}

- (void)reader:(id<SJDataReader>)reader anErrorOccurred:(NSError *)error {
    [self callbackWithBlock:^{
        [self.delegate reader:self anErrorOccurred:error];
    }];
}
@end
