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

- (instancetype)initWithURL:(NSURL *)URL requestHeaders:(NSDictionary *)headers range:(NSRange)range {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _requestHeaders = headers.copy;
        _range = range;
        _semaphore = dispatch_semaphore_create(1);
        _delegateQueue = dispatch_get_global_queue(0, 0);
    }
    return self;
}

- (NSString *)description {
    [self lock];
    @try {
        return [NSString stringWithFormat:@"SJResourceNetworkDataReader:<%p> { URL: %@, headers: %@, range: %@, response: %@\n};", self, _URL, _requestHeaders, NSStringFromRange(_range), _response];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
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
        NSMutableURLRequest *request = [NSMutableURLRequest.alloc initWithURL:_URL];
        [request setAllHTTPHeaderFields:_requestHeaders];
        [request setValue:[NSString stringWithFormat:@"bytes=%lu-%lu", (unsigned long)_range.location, (unsigned long)_range.length - 1] forHTTPHeaderField:@"Range"];
        self.task = [SJDownload.shared downloadWithRequest:request delegate:self];
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
    [self lock];
    @try {
        if ( self.isClosed )
            return nil;
        
        if ( _offset < self.downloadedLength ) {
            NSUInteger length = MIN(lengthParam, self.downloadedLength - _offset);
            if ( length > 0 ) {
                NSData *data = [self.reader readDataOfLength:length];
                _offset += data.length;
                return data;
            }
        }
        
        return nil;
    } @catch (NSException *exception) {
        [self _onError:[SJError errorForException:exception]];
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
        if ( self.task.state == NSURLSessionTaskStateRunning ) [self.task cancel];
        self.task = nil;
        [self.writer synchronizeFile];
        [self.writer closeFile];
        self.writer = nil;
        [self.reader closeFile];
        self.reader = nil;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
     
#ifdef DEBUG
    NSLog(@"[%@ close];", self);
#endif
}

#pragma mark -

- (void)downloadTask:(NSURLSessionTask *)task didReceiveResponse:(NSHTTPURLResponse *)response {
    [self lock];
    @try {
        if ( self.isClosed )
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
        if ( self.isClosed )
            return;

        [_writer writeData:data];
        self.downloadedLength += data.length;
        self.content.length += self.downloadedLength;
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
        if ( self.isClosed )
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
