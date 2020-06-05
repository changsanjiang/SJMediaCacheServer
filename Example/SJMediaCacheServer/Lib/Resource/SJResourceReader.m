//
//  SJResourceReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceReader.h"
#import "SJResource+SJPrivate.h"
#import "SJResourcePartialContent.h"
#import "SJResourceResponse.h"
#import "SJResourceFileManager.h"
#import "SJResourceFileDataReader.h"
#import "SJResourceNetworkDataReader.h"
 
@interface SJResourceReader ()<NSLocking, SJResourceDataReaderDelegate>
@property (nonatomic, strong) dispatch_queue_t delegateQueue;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isPrepared;
@property (nonatomic) BOOL isClosed;

@property (nonatomic) NSInteger currentIndex;
@property (nonatomic, strong, nullable) id<SJResourceDataReader> currentReader;
@property (nonatomic, strong, nullable) SJResourceNetworkDataReader *tmpReader; // 用于获取资源contentLength, contentType等信息
@property (nonatomic) NSUInteger offset;

@property (nonatomic, weak, nullable) SJResource *resource;
@property (nonatomic, strong) SJDataRequest *request;
@property (nonatomic, copy, nullable) NSArray<id<SJResourceDataReader>> *readers;
@property (nonatomic, strong, nullable) id<SJResourceResponse> response;
@end

@implementation SJResourceReader

- (instancetype)initWithResource:(__weak SJResource *)resource request:(SJDataRequest *)request {
    self = [super init];
    if ( self ) {
        _delegateQueue = dispatch_get_global_queue(0, 0);
        _semaphore = dispatch_semaphore_create(1);
        _currentIndex = NSNotFound;

        _resource = resource;
        _request = request;
    }
    return self;
}

- (void)dealloc {
#ifdef DEBUG
    printf("SJResourceReader: <%p>.dealloc;\n\n", self);
#endif
}

- (void)prepare {
    [self lock];
    @try {
        if ( _isClosed || _isCalledPrepare )
            return;
         
#ifdef DEBUG
        printf("\nSJResourceReader: <%p>.prepare { range: %s }];\n", self, NSStringFromRange(_request.range).UTF8String);
#endif
        
        _isCalledPrepare = YES;
        
        if ( _resource.totalLength == 0 || _resource.contentType.length == 0 ) {
            _tmpReader = [SJResourceNetworkDataReader.alloc initWithURL:_request.URL requestHeaders:_request.headers range:NSMakeRange(0, 1) totalLength:NSNotFound];
            [_tmpReader setDelegate:self delegateQueue:_delegateQueue];
            [_tmpReader prepare];
        }
        else {
            _response = [SJResourceResponse.alloc initWithServer:_resource.server contentType:_resource.contentType totalLength:_resource.totalLength contentRange:_request.range];
            [self _createSubreaders];
            [self _prepareNextReader];
        }
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
            [self _prepareNextReader];
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

- (void)_createSubreaders {
    NSAssert(_response != nil, @"`response`不能为`nil`!");
     
    // `length`经常变动, 就在这里排序吧
    __auto_type contents = [_resource.contents sortedArrayUsingComparator:^NSComparisonResult(SJResourcePartialContent *obj1, SJResourcePartialContent *obj2) {
        if ( obj1.offset == obj2.offset )
            return obj1.length >= obj2.length ? NSOrderedAscending : NSOrderedDescending;
        return obj1.offset < obj2.offset ? NSOrderedAscending : NSOrderedDescending;
    }];
    
    NSRange current = _request.range;
    NSUInteger totalLength = _response.totalLength;
    // bytes=-500
    if      ( current.location == NSNotFound && current.length != NSNotFound )
        current.location = totalLength - current.length;
    // bytes=9500-
    else if ( current.location != NSNotFound && current.length == NSNotFound ) {
        current.length = totalLength - current.location;
    }
    else {
        current.location = 0;
        current.length = totalLength;
    }
    
    NSMutableArray<id<SJResourceDataReader>> *readers = NSMutableArray.array;
    for ( SJResourcePartialContent *content in contents ) {
        NSRange available = NSMakeRange(content.offset, content.length);
        NSRange intersection = NSIntersectionRange(current, available);
        if ( intersection.length != 0 ) {
            // undownloaded part
            NSRange leftRange = NSMakeRange(current.location, intersection.location - current.location);
            if ( leftRange.length != 0 ) {
                SJResourceNetworkDataReader *reader = [SJResourceNetworkDataReader.alloc initWithURL:_request.URL requestHeaders:_request.headers range:leftRange totalLength:totalLength];
                [readers addObject:reader];
            }
            
            // downloaded part
            NSRange matchedRange = NSMakeRange(NSMaxRange(leftRange), intersection.length);
            NSRange fileRange = NSMakeRange(matchedRange.location - content.offset, intersection.length);
            NSString *path = [SJResourceFileManager getContentFilePathWithName:content.name inResource:_resource.name];
            SJResourceFileDataReader *reader = [SJResourceFileDataReader.alloc initWithRange:matchedRange path:path readRange:fileRange];
            [readers addObject:reader];
            
            // next part
            current = NSMakeRange(NSMaxRange(intersection), NSMaxRange(_request.range) - NSMaxRange(intersection));
        }
        
        if ( current.length == 0 || available.location > NSMaxRange(current) ) break;
    }
    
    if ( current.length != 0 ) {
        // undownloaded part
        SJResourceNetworkDataReader *reader = [SJResourceNetworkDataReader.alloc initWithURL:_request.URL requestHeaders:_request.headers range:current totalLength:totalLength];
        [readers addObject:reader];
    }
    
    _readers = readers.copy;
    
#ifdef DEBUG
    printf("\nSJResourceReader: <%p>.createSubreaders { range: %s, count: %lu }];\n", self, NSStringFromRange(_request.range).UTF8String, _readers.count);
#endif
}

- (void)_prepareNextReader {
    [self.currentReader close];

    if ( self.currentReader == self.readers.lastObject )
        return;
    
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
        else if ( reader == _tmpReader ) {
            // create response
            _response = [SJResourceResponse.alloc initWithResponse:_tmpReader.response];
            [_tmpReader close];
            _tmpReader = nil;
            
            // update contentType & totalLength & server for `resource`
            SJResource *resource = [SJResource resourceWithURL:_request.URL];
            [resource setServer:_response.server contentType:_response.contentType totalLength:_response.totalLength];
            
            // prepare
            [self _createSubreaders];
            [self _prepareNextReader];
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
