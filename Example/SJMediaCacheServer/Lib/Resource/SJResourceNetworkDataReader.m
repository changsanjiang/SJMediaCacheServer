//
//  SJResourceNetworkDataReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceNetworkDataReader.h"
#import "SJError.h"
#import "SJDownload.h"
#import "SJResource.h"
#import "SJResourceResponse.h"
#import "SJResourcePartialContent.h"

@interface SJResourceNetworkDataReader ()<SJDownloadTaskDelegate, NSLocking>
@property (nonatomic, weak, nullable) id<SJResourceDataReaderDelegate> delegate;
@property (nonatomic, strong) dispatch_queue_t delegateQueue;
@property (nonatomic, strong) dispatch_semaphore_t semaphore;

@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, copy) NSDictionary *requestHeaders;
@property (nonatomic) NSRange range;
@property (nonatomic) NSUInteger totalLength;

@property (nonatomic, strong, nullable) NSURLSessionTask *task;
@property (nonatomic, strong, nullable) NSHTTPURLResponse *response;

@property (nonatomic, strong, nullable) NSFileHandle *reader;
@property (nonatomic, strong, nullable) NSFileHandle *writer;

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isClosed;

@property (nonatomic, strong, nullable) SJResourcePartialContent *content;
@property (nonatomic) NSUInteger downloadedLength;
@property (nonatomic) NSUInteger offset;
@end

@implementation SJResourceNetworkDataReader

- (instancetype)initWithURL:(NSURL *)URL requestHeaders:(NSDictionary *)headers range:(NSRange)range totalLength:(NSUInteger)totalLength {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _requestHeaders = headers.copy;
        _range = range;
        _totalLength = totalLength;
        _semaphore = dispatch_semaphore_create(1);
        _delegateQueue = dispatch_get_global_queue(0, 0);
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"SJResourceNetworkDataReader:<%p> { URL: %@, headers: %@, range: %@\n};", self, _URL, _requestHeaders, NSStringFromRange(_range)];
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
        printf("SJResourceNetworkDataReader: <%p>.prepare { range: %s };\n", self, NSStringFromRange(_range).UTF8String);
#endif
        _isCalledPrepare = YES;
        NSMutableURLRequest *request = [NSMutableURLRequest.alloc initWithURL:_URL];
        [request setAllHTTPHeaderFields:_requestHeaders];
//
//        https://tools.ietf.org/html/rfc7233#section-4.1
//
//        Additional examples, assuming a representation of length 10000:
//
//        o  The final 500 bytes (byte offsets 9500-9999, inclusive):
//
//             bytes=-500
//
//        Or:
//
//             bytes=9500-
//
//        o  The first and last bytes only (bytes 0 and 9999):
//
//             bytes=0-0,-1
//
//        o  Other valid (but not canonical) specifications of the second 500
//           bytes (byte offsets 500-999, inclusive):
//
//             bytes=500-600,601-999
//             bytes=500-700,601-999
//
        if ( _totalLength == NSMaxRange(_range) ) {
            [request setValue:[NSString stringWithFormat:@"bytes=%lu-", (unsigned long)_range.location] forHTTPHeaderField:@"Range"];
        }
        else {
            [request setValue:[NSString stringWithFormat:@"bytes=%lu-%lu", (unsigned long)_range.location, (unsigned long)NSMaxRange(_range) - 1] forHTTPHeaderField:@"Range"];
        }
        _task = [SJDownload.shared downloadWithRequest:request delegate:self];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSHTTPURLResponse *)response {
    [self lock];
    @try {
        return _response;
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
        return _offset == _range.length;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (nullable NSData *)readDataOfLength:(NSUInteger)lengthParam {
    if ( self.isDone )
        return nil;

    [self lock];
    @try {
        if ( _isClosed )
            return nil;
        
        NSData *data = nil;
        
        if ( _offset < _downloadedLength ) {
            NSUInteger length = MIN(lengthParam, _downloadedLength - _offset);
            if ( length > 0 ) {
                data = [_reader readDataOfLength:length];
                _offset += data.length;
                
#ifdef DEBUG
                printf("SJResourceNetworkDataReader: <%p>.read { offset: %lu };\n", self, _offset);
                if ( _offset == _range.length ) {
                    printf("SJResourceNetworkDataReader: <%p>.done { range: %s };\n", self, NSStringFromRange(_range).UTF8String);
                }
#endif
            }
        }
        
        return data;
    } @catch (NSException *exception) {
        [self _onError:[SJError errorForException:exception]];
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
        if ( _task.state == NSURLSessionTaskStateRunning ) [_task cancel];
        _task = nil;
        [_writer synchronizeFile];
        [_writer closeFile];
        _writer = nil;
        [_reader closeFile];
        _reader = nil;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
     
#ifdef DEBUG
    printf("SJResourceNetworkDataReader: <%p>.close;\n", self);
#endif
}

#pragma mark -

- (void)downloadTask:(NSURLSessionTask *)task didReceiveResponse:(NSHTTPURLResponse *)response {
    [self lock];
    @try {
        if ( _isClosed )
            return;
        _response = response;

        SJResource *resource = [SJResource resourceWithURL:_URL];
        _content = [resource createContentWithOffset:_range.location];
        
        NSString *filePath = [resource filePathOfContent:_content];
        _reader = [NSFileHandle fileHandleForReadingAtPath:filePath];
        _writer = [NSFileHandle fileHandleForWritingAtPath:filePath];
        
        [self callbackWithBlock:^{
            [self.delegate readerPrepareDidFinish:self];
        }];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)downloadTask:(NSURLSessionTask *)task didReceiveData:(NSData *)data {
    [self lock];
    @try {
        if ( _isClosed )
            return;

        [_writer writeData:data];
        _downloadedLength += data.length;
        _content.length = _downloadedLength;
        
#ifdef DEBUG
        printf("SJResourceNetworkDataReader: <%p>.downloadProgress: %lu;\n", self, _downloadedLength);
#endif
        
        [self callbackWithBlock:^{
            [self.delegate readerHasAvailableData:self];
        }];
    } @catch (NSException *exception) {
        [self _onError:[SJError errorForException:exception]];
    } @finally {
        [self unlock];
    }
}

- (void)downloadTask:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [self lock];
    @try {
        if ( _isClosed )
            return;
        
        if ( error != nil && error.code != NSURLErrorCancelled ) {
            [self _onError:error];
        }
        else {
            // finished download
        }
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)_onError:(NSError *)error {
    [self callbackWithBlock:^{
        [self.delegate reader:self anErrorOccurred:error];
    }];
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
@end
