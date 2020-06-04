//
//  SJResourceReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceReader.h"
#import "SJResource+SJPrivate.h"
#import "SJResourceResponse.h"
#import "SJResourceNetworkDataReader.h"

@interface SJResourceReader ()<NSLocking, SJResourceDataReaderDelegate>
@property (nonatomic, strong) dispatch_queue_t delegateQueue;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;

@property (nonatomic, strong) SJDataRequest *request;
@property (nonatomic, copy) NSArray<id<SJResourceDataReader>> *readers;
@property (nonatomic, strong, nullable) id<SJResourceResponse> response;

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isPrepared;
@property (nonatomic) BOOL isClosed;

@property (nonatomic) NSInteger currentIndex;
@property (nonatomic, strong, nullable) id<SJResourceDataReader> currentReader;
@property (nonatomic, strong, nullable) SJResourceNetworkDataReader *tmpReader; // header丢失的情况下使用
@property (nonatomic) NSUInteger offset;
@end

@implementation SJResourceReader
- (instancetype)initWithRequest:(SJDataRequest *)request readers:(NSArray<id<SJResourceDataReader>> *)readers presetResponse:(nullable SJResourceResponse *)response {
    self = [super init];
    if ( self ) {
        _request = request;
        _response = response;
        _delegateQueue = dispatch_get_global_queue(0, 0);
        _semaphore = dispatch_semaphore_create(1);
        _readers = readers.copy;
        _currentIndex = NSNotFound;
    }
    return self;
}

- (void)prepare {
    [self lock];
    @try {
        if ( _isClosed || _isCalledPrepare )
            return;
        
#ifdef DEBUG
        printf("\nSJResourceReader: <%p>.init { range: %s }];\n", self, NSStringFromRange(_request.range).UTF8String);
#endif
        
        _isCalledPrepare = YES;
        
        // 处理 header 丢失的情况
        if ( _response == nil && ![_readers.firstObject isKindOfClass:SJResourceNetworkDataReader.class] ) {
            _tmpReader = [SJResourceNetworkDataReader.alloc initWithURL:_request.URL requestHeaders:_request.headers range:NSMakeRange(0, 1)];
            [_tmpReader setDelegate:self delegateQueue:_delegateQueue];
            [_tmpReader prepare];
        }

        [self prepareNextReader];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    [self lock];
    @try {
        if ( _isClosed || _currentIndex == NSNotFound )
            return nil;
        
        NSData *data = [self.currentReader readDataOfLength:length];
        _offset += data.length;
        if ( self.currentReader.isDone )
            [self prepareNextReader];
        return data;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (id<SJResourceResponse>)response {
    [self lock];
    @try {
        return _response;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}
 
- (BOOL)isPrepared {
    [self lock];
    @try {
        return _isPrepared;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (BOOL)isReadingEndOfData {
    [self lock];
    @try {
        return _readers.lastObject.isDone;
    } @catch (__unused NSException *exception) {
        
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
        for ( id<SJResourceDataReader> reader in _readers ) {
            [reader close];
        }
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
    
#ifdef DEBUG
    printf("SJResourceReader: <%p>.close;\n\n", self);
#endif
}

#pragma mark -

- (void)prepareNextReader {
    [self.currentReader close];
    if ( self.currentIndex == NSNotFound )
        self.currentIndex = 0;
    else
        self.currentIndex += 1;
    [self.currentReader setDelegate:self delegateQueue:self.delegateQueue];
    [self.currentReader prepare];
}

- (nullable id<SJResourceDataReader>)currentReader {
    if ( self.currentIndex != NSNotFound && self.currentIndex < self.readers.count ) {
        return self.readers[_currentIndex];
    }
    return nil;
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

- (void)readerPrepareDidFinish:(id<SJResourceDataReader>)reader {
    if ( self.isPrepared )
        return;
    
    [self lock];
    @try {
        if      ( _response != nil ) {
            _isPrepared = YES;
        }
        else if ( [reader isKindOfClass:SJResourceNetworkDataReader.class] ) {
            SJResourceNetworkDataReader *networkReader = (SJResourceNetworkDataReader *)reader;
            _response = [SJResourceResponse.alloc initWithResponse:networkReader.response];
            
            if ( networkReader == _tmpReader ) {
                [_tmpReader close];
                _tmpReader = nil;
            }
            _isPrepared = YES;
            
            // update resource
            SJResource *resource = [SJResource resourceWithURL:_request.URL];
            [resource setServer:_response.server contentType:_response.contentType totalLength:_response.totalLength];
        }

        [self callbackWithBlock:^{
            [self.delegate readerPrepareDidFinish:self];
        }];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)readerHasAvailableData:(id<SJResourceDataReader>)reader {
    [self callbackWithBlock:^{
        [self.delegate readerHasAvailableData:self];
    }];
}

- (void)reader:(id<SJResourceDataReader>)reader anErrorOccurred:(NSError *)error {
    [self callbackWithBlock:^{
        [self.delegate reader:self anErrorOccurred:error];
    }];
}
@end
