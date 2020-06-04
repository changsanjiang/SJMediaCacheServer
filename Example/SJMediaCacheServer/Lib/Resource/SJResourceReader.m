//
//  SJResourceReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceReader.h"
#import "SJResourceResponse.h"
#import "SJResourceNetworkDataReader.h"

@interface SJResourceReader ()<NSLocking, SJResourceDataReaderDelegate>
@property (nonatomic, strong) dispatch_queue_t delegateQueue;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;

@property (nonatomic, strong) SJDataRequest *request;
@property (nonatomic, copy) NSArray<id<SJResourceDataReader>> *readers;

@property (nonatomic, copy, nullable) NSDictionary *presetResponseHeaders;
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
- (instancetype)initWithRequest:(SJDataRequest *)request readers:(NSArray<id<SJResourceDataReader>> *)readers presetResponseHeaders:(NSDictionary *)headers {
    self = [super init];
    if ( self ) {
        _request = request;
        _presetResponseHeaders = headers.copy;
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
        if ( self.isClosed || self.isCalledPrepare )
            return;
        
        self.isCalledPrepare = YES;
        [self prepareNextReader];
        // header丢失
        if ( self.presetResponseHeaders == nil && ![self.readers.firstObject isKindOfClass:SJResourceNetworkDataReader.class] ) {
            self.tmpReader = [SJResourceNetworkDataReader.alloc initWithURL:_request.URL requestHeaders:_request.headers range:NSMakeRange(0, 1)];
            [self.tmpReader setDelegate:self delegateQueue:self.delegateQueue];
            [self.tmpReader prepare];
        }
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
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
        for ( id<SJResourceDataReader> reader in self.readers ) {
            [reader close];
        }
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
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
    [self lock];
    @try {
        if ( self.isPrepared == NO ) {
            
#warning next .. responseHeader 的保存
            
            if      ( self.presetResponseHeaders != nil ) {
                self.response = [SJResourceResponse.alloc initWithRange:self.request.range allHeaderFields:self.presetResponseHeaders];
                self.isPrepared = YES;
            }
            else if ( [reader isKindOfClass:SJResourceNetworkDataReader.class] ) {
                SJResourceNetworkDataReader *networkReader = (SJResourceNetworkDataReader *)reader;
                self.response = [SJResourceResponse.alloc initWithRange:self.request.range allHeaderFields:networkReader.response.responseHeaders];
                if ( networkReader == self.tmpReader ) {
                    [self.tmpReader close];
                    self.tmpReader = nil;
                }
                self.isPrepared = YES;
            }
            
            [self callbackWithBlock:^{
                [self.delegate readerPrepareDidFinish:self];
            }];
        }
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
