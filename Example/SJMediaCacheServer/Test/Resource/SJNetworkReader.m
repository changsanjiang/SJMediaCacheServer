//
//  SJNetworkReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJNetworkReader.h"
#import "SJError.h"
#import "SJDownload.h"
#import "SJResource.h"
#import "SJResourcePartialContent.h"

@interface SJResource (Private)
- (NSString *)filePathWithContent:(SJResourcePartialContent *)content;
- (SJResourcePartialContent *)newContentWithOffset:(UInt64)offset;
@end

@interface SJNetworkReader ()<SJDownloadTaskDelegate, NSLocking>
@property (nonatomic, strong, nullable) dispatch_queue_t delegateQueue;

@property (nonatomic, strong) SJDataRequest *request;
@property (nonatomic, strong) NSURLSessionTask *task;

@property (nonatomic, strong) NSFileHandle *reader;
@property (nonatomic, strong) NSFileHandle *writer;

@property (nonatomic) BOOL isPreparing;
@property (nonatomic) BOOL isClosed;

@property (nonatomic, strong) SJResourcePartialContent *content;
@property (nonatomic) UInt64 downloadedLength;
@property (nonatomic) UInt64 offset;
@property (nonatomic, strong) NSError *error;

@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@end

@implementation SJNetworkReader
@synthesize delegate = _delegate;

- (instancetype)initWithRequest:(SJDataRequest *)request {
    self = [super init];
    if ( self ) {
        _request = request;
        _semaphore = dispatch_semaphore_create(1);
        _delegateQueue = dispatch_get_global_queue(0, 0);
    }
    return self;
}

- (void)setDelegate:(id<SJReaderDelegate>)delegate delegateQueue:(nonnull dispatch_queue_t)queue {
    [self lock];
    self.delegate = delegate;
    self.delegateQueue = queue;
    [self unlock];
}

- (void)prepare {
    [self lock];
    @try {
        if ( self.isClosed || self.isPreparing )
            return;
        
        self.isPreparing = YES;
        NSMutableURLRequest *request = [NSMutableURLRequest.alloc initWithURL:_request.URL];
        [request setAllHTTPHeaderFields:_request.headers];
        [request setValue:[NSString stringWithFormat:@"bytes=%lu-%lu", (unsigned long)_request.range.location, (unsigned long)_request.range.length - 1] forHTTPHeaderField:@"Range"];
        self.task = [SJDownload.shared downloadWithRequest:request delegate:self];
    } @finally {
        [self unlock];
    }
}

- (nullable NSData *)readDataOfLength:(NSUInteger)lengthParam {
    [self lock];
    @try {
        UInt64 length = MIN(lengthParam, self.downloadedLength - self.offset);
        if ( length > 0 ) {
            NSData *data = [self.reader readDataOfLength:length];
            self.offset += length;
            return data;
        }
    } @catch (NSException *exception) {
        [self _onError:[SJError errorForException:exception]];
    } @finally {
        [self unlock];
    }
    return nil;
}

- (void)close {
    [self lock];
    @try {
        if ( self.isClosed )
            return;
        
        self.isClosed = YES;
        if ( self.task.state == NSURLSessionTaskStateRunning ) [self.task cancel];
    } @finally {
        [self unlock];
    }
}

#pragma mark -

- (void)downloadTask:(NSURLSessionTask *)task didReceiveResponse:(NSURLResponse *)response {
    [self lock];
    @try {
        SJResource *resource = [SJResource resourceWithURL:_request.URL];
        _content = [resource newContentWithOffset:_request.range.location];
        NSString *filePath = [resource filePathWithContent:_content];
        _reader = [NSFileHandle fileHandleForReadingAtPath:filePath];
        _writer = [NSFileHandle fileHandleForWritingAtPath:filePath];
        [self callbackWithBlock:^{
            [self.delegate readerPrepareDidFinish:self];
        }];
    } @finally {
        [self unlock];
    }
}

- (void)downloadTask:(NSURLSessionTask *)task didReceiveData:(NSData *)data {
    [self lock];
    @try {
        [_writer writeData:data];
        self.downloadedLength += data.length;
        [self.content updateLength:self.downloadedLength];
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
            // finished
        }
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
