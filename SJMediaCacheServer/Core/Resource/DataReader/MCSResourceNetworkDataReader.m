//
//  MCSResourceNetworkDataReader.m
//  Pods
//
//  Created by BlueDancer on 2020/8/5.
//

#import "MCSResourceNetworkDataReader.h"
#import "MCSResourceDataReaderSubclass.h"
#import "MCSDownload.h"
#import "NSURLRequest+MCS.h"
#import "MCSResource.h"
#import "MCSResourcePartialContent.h"
#import "MCSUtils.h"
#import "MCSURLRecognizer.h"

@interface MCSResourceNetworkDataReader ()<MCSDownloadTaskDelegate>
@property (nonatomic, strong, nullable) NSURLRequest *request;
@property (nonatomic) float networkTaskPriority;
@property (nonatomic, strong, nullable) NSURLSessionTask *task;
@property (nonatomic, strong, nullable) MCSResourcePartialContent *content;
@property (nonatomic, strong, nullable) NSFileHandle *writer;
@end

@implementation MCSResourceNetworkDataReader

- (instancetype)initWithResource:(__weak MCSResource *)resource proxyRequest:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority delegate:(id<MCSResourceDataReaderDelegate>)delegate {
    self = [super initWithResource:resource delegate:delegate];
    if ( self ) {
        _request = request;
        _networkTaskPriority = networkTaskPriority;
    }
    return self;
}

- (void)dealloc {
    if ( !_isClosed ) [self _close];
}

- (void)_prepare {
    _isCalledPrepare = YES;
    
    MCSDataReaderLog(@"%@: <%p>.prepare { request: %@ };\n", NSStringFromClass(self.class), self, _request.mcs_description);
    
    NSURL *proxyURL = _request.URL;
    MCSDataType dataType = [MCSURLRecognizer.shared dataTypeForProxyURL:proxyURL];
    NSURL *URL = [MCSURLRecognizer.shared URLWithProxyURL:proxyURL];
    NSMutableURLRequest *request = [_request mcs_requestWithRedirectURL:URL];
    [request mcs_requestWithHTTPAdditionalHeaders:[_resource.configuration HTTPAdditionalHeadersForDataRequestsOfType:dataType]];
    _task = [MCSDownload.shared downloadWithRequest:request priority:_networkTaskPriority delegate:self];
}

- (void)_onError:(NSError *)error {
    [self _close];
    
    dispatch_async(MCSDelegateQueue(), ^{
        [self->_delegate reader:self anErrorOccurred:error];
    });
}

- (void)_close {
    if ( _isClosed )
        return;
    
    @try {
        [_task cancel];
        _task = nil;
        [_writer synchronizeFile];
        [_writer closeFile];
        _writer = nil;
        [_reader closeFile];
        _reader = nil;
        _isClosed = YES;
        [_resource didEndReadContent:_content];
        MCSDataReaderLog(@"%@: <%p>.close;\n", NSStringFromClass(self.class), self);
    } @catch (__unused NSException *exception) {
        
    }
}

#pragma mark - MCSDownloadTaskDelegate

- (void)downloadTask:(NSURLSessionTask *)task didReceiveResponse:(NSHTTPURLResponse *)response {
    dispatch_barrier_sync(MCSResourceDataReaderQueue(), ^{
        if ( _isClosed || _resource == nil ) {
            [self _close];
            return;
        }

        _content = [_resource createContentForDataReaderWithProxyURL:_request.URL response:response];
        if ( _content == nil ) {
            [self _onError:[NSError mcs_responseUnavailable:task.currentRequest.URL request:_request response:response]];
            return;
        }
        
        NSRange range = _request.mcs_range;
        if ( range.location == NSNotFound ) range.location = 0;
        range.length = MCSGetResponseContentLength(response);
        _range = range;
        NSString *filePath = [_resource filePathOfContent:_content];
        _reader = [NSFileHandle fileHandleForReadingAtPath:filePath];
        _writer = [NSFileHandle fileHandleForWritingAtPath:filePath];
        
        if ( _writer != nil ) {
            @try {
                [_writer seekToEndOfFile];
            } @catch (NSException *exception) {
                [task cancel];
                [self _onError:[NSError mcs_exception:exception]];
            }
        }
        
        if ( _reader == nil || _writer == nil ) {
            [self _onError:[NSError mcs_fileNotExistError:@{
                MCSErrorUserInfoResourceKey : _resource,
                MCSErrorUserInfoRequestKey : _request
            }]];
            return;
        }
        
        _isPrepared = YES;
        dispatch_async(MCSDelegateQueue(), ^{
            [self->_delegate readerPrepareDidFinish:self];
        });
    });
}

- (void)downloadTask:(NSURLSessionTask *)task didReceiveData:(NSData *)data {
    dispatch_barrier_sync(MCSResourceDataReaderQueue(), ^{
        @try {
            if ( _isClosed || _resource == nil ) {
                [task cancel];
                [self _close];
                return;
            }
            
            [_writer writeData:data];
            NSUInteger length = data.length;
            _availableLength += length;
            [_resource didWriteDataForContent:_content length:length];
            dispatch_async(MCSDelegateQueue(), ^{
                [self->_delegate reader:self hasAvailableDataWithLength:length];
            });
        } @catch (NSException *exception) {
            [self _onError:[NSError mcs_exception:exception]];
        }
    });
}

- (void)downloadTask:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    dispatch_barrier_sync(MCSResourceDataReaderQueue(), ^{
       if ( _isClosed )
           return;
        
        if ( error != nil && error.code != NSURLErrorCancelled ) {
            [self _onError:error];
        }
        //    else {
        //        // finished download
        //    }
    });
}

@end
