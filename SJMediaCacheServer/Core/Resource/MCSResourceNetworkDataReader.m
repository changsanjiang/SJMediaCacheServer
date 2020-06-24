//
//  MCSResourceNetworkDataReader.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResourceNetworkDataReader.h"
#import "MCSError.h"
#import "MCSDownload.h"
#import "MCSResourceResponse.h"
#import "MCSResourcePartialContent.h"
#import "MCSLogger.h"

@interface MCSResourceNetworkDataReader ()<MCSDownloadTaskDelegate>
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic) NSRange range;

@property (nonatomic, strong, nullable) NSURLSessionTask *task;
@property (nonatomic, strong, nullable) NSHTTPURLResponse *response;

@property (nonatomic, strong, nullable) NSFileHandle *reader;
@property (nonatomic, strong, nullable) NSFileHandle *writer;

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isClosed;
@property (nonatomic) BOOL isDone;

@property (nonatomic, strong, nullable) MCSResourcePartialContent *content;
@property (nonatomic) NSUInteger downloadedLength;
@property (nonatomic) NSUInteger offset;

@property (nonatomic) float networkTaskPriority;
@end

@implementation MCSResourceNetworkDataReader
@synthesize delegate = _delegate;
@synthesize delegateQueue = _delegateQueue;
@synthesize isPrepared = _isPrepared;

- (instancetype)initWithRequest:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority delegate:(id<MCSResourceDataReaderDelegate>)delegate delegateQueue:(dispatch_queue_t)queue {
    self = [super init];
    if ( self ) {
        _request = request;
        _networkTaskPriority = networkTaskPriority;
        _delegate = delegate;
        _delegateQueue = queue;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"MCSResourceNetworkDataReader:<%p> { URL: %@, headers: %@, range: %@\n};", self, _request.URL, _request.mcs_headers, NSStringFromRange(_request.mcs_range)];
}

- (void)prepare {
    if ( _isClosed || _isCalledPrepare )
        return;
    
    MCSLog(@"%@: <%p>.prepare { range: %@ };\n", NSStringFromClass(self.class), self, NSStringFromRange(_range));
    
    _isCalledPrepare = YES;
    
    _task = [MCSDownload.shared downloadWithRequest:_request priority:_networkTaskPriority delegate:self];
}

- (nullable NSData *)readDataOfLength:(NSUInteger)lengthParam {
    @try {
        if ( _isClosed || _isDone || !_isPrepared )
            return nil;
        
        NSData *data = nil;
        
        if ( _offset < _downloadedLength ) {
            NSUInteger length = MIN(lengthParam, _downloadedLength - _offset);
            if ( length > 0 ) {
                data = [_reader readDataOfLength:length];

                MCSLog(@"%@: <%p>.read { offset: %lu, length: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)_offset, (unsigned long)data.length);

                _offset += data.length;
                _isDone = _offset == _range.length;
                
            }
        }
        return data;
    } @catch (NSException *exception) {
        [self _onError:[NSError mcs_exception:exception]];
    }
#ifdef DEBUG
    @finally {
        if ( _isDone ) {
            MCSLog(@"%@: <%p>.done { range: %@ };\n", NSStringFromClass(self.class), self, NSStringFromRange(_range));
        }
    }
#endif
}

- (void)close {
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
        
    }
#ifdef DEBUG
    @finally {
        MCSLog(@"%@: <%p>.close;\n", NSStringFromClass(self.class), self);
    }
#endif
}

#pragma mark -

- (void)downloadTask:(NSURLSessionTask *)task didReceiveResponse:(NSHTTPURLResponse *)response {
    if ( _isClosed )
        return;
    _response = response;
    
    id<MCSResourceNetworkDataReaderDelegate> delegate = (id)self.delegate;
    _content = [delegate newPartialContentForReader:self];
    NSString *filePath = [delegate writePathOfPartialContent:_content];
    _reader = [NSFileHandle fileHandleForReadingAtPath:filePath];
    _writer = [NSFileHandle fileHandleForWritingAtPath:filePath];

    if ( _reader == nil || _writer == nil ) {
        [self _onError:[NSError mcs_fileNotExistError:_request.URL]];
        return;
    }
    
    _isPrepared = YES;
    
    dispatch_async(_delegateQueue, ^{
        [self.delegate readerPrepareDidFinish:self];
    });

}

- (void)downloadTask:(NSURLSessionTask *)task didReceiveData:(NSData *)data {
    @try {
        if ( _isClosed )
            return;

        [_writer writeData:data];
        NSUInteger length = data.length;
        _downloadedLength += length;
        [_content didWriteDataWithLength:length];
     
        dispatch_async(_delegateQueue, ^{
            [self.delegate readerHasAvailableData:self];
        });
    } @catch (NSException *exception) {
        [self _onError:[NSError mcs_exception:exception]];
    }
}

- (void)downloadTask:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if ( _isClosed )
        return;
    
    if ( error != nil && error.code != NSURLErrorCancelled ) {
        [self _onError:error];
    }
//    else {
//        // finished download
//    }
}

#pragma mark -

- (void)_onError:(NSError *)error {
    [self close];
    
    dispatch_async(_delegateQueue, ^{
        [self.delegate reader:self anErrorOccurred:error];
    });
}
@end
