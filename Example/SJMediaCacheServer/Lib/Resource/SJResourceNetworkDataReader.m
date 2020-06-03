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
#import "SJResourcePartialContent.h"

@interface SJResource (Private)
- (NSString *)filePathWithContent:(SJResourcePartialContent *)content;
- (SJResourcePartialContent *)newContentWithOffset:(UInt64)offset;
@end

@interface SJResourceNetworkDataReader ()<SJDownloadTaskDelegate, NSLocking>
@property (nonatomic, strong, nullable) dispatch_queue_t delegateQueue;
@property (nonatomic, weak) id<SJResourceDataReaderDelegate> delegate;

@property (nonatomic, strong) SJDataRequest *request;
@property (nonatomic, strong) NSURLSessionTask *task;

@property (nonatomic, strong) NSFileHandle *reader;
@property (nonatomic, strong) NSFileHandle *writer;

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isClosed;

@property (nonatomic, strong) SJResourcePartialContent *content;
@property (nonatomic) UInt64 downloadedLength;
@property (nonatomic, strong) NSError *error;

@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@end

@implementation SJResourceNetworkDataReader
- (instancetype)initWithRequest:(SJDataRequest *)request {
    self = [super init];
    if ( self ) {
        _request = request;
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
        NSMutableURLRequest *request = [NSMutableURLRequest.alloc initWithURL:_request.URL];
        [request setAllHTTPHeaderFields:_request.headers];
        [request setValue:[NSString stringWithFormat:@"bytes=%lu-%lu", (unsigned long)_request.range.location, (unsigned long)_request.range.length - 1] forHTTPHeaderField:@"Range"];
        self.task = [SJDownload.shared downloadWithRequest:request delegate:self];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (UInt64)offset {
    [self lock];
    @try {
        return self.reader.offsetInFile;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (BOOL)isDone {
    [self lock];
    @try {
        return self.reader.offsetInFile == self.request.range.length;
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
        
        UInt64 offset = self.reader.offsetInFile;
        if ( offset < self.downloadedLength ) {
            UInt64 length = MIN(lengthParam, self.downloadedLength - self.reader.offsetInFile);
            if ( length > 0 ) {
                NSData *data = [self.reader readDataOfLength:length];
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
}

#pragma mark -

- (void)downloadTask:(NSURLSessionTask *)task didReceiveResponse:(NSURLResponse *)response {
    [self lock];
    @try {
        if ( self.isClosed )
            return;
        
        SJResource *resource = [SJResource resourceWithURL:_request.URL];
        _content = [resource newContentWithOffset:_request.range.location];
        NSString *filePath = [resource filePathWithContent:_content];
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
