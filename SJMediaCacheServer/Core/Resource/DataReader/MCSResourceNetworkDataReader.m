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
#import "MCSContentNetworkReadwrite.h"

@interface MCSResourceNetworkDataReader ()<MCSDownloadTaskDelegate>
@property (nonatomic, strong, nullable) NSURLRequest *request;
@property (nonatomic) float networkTaskPriority;
@property (nonatomic, strong, nullable) NSURLSessionTask *task;
@property (nonatomic, strong, nullable) MCSResourcePartialContent *content;
//@property (nonatomic, strong, nullable) NSFileHandle *writer;
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
        _reader = nil;
        _isClosed = YES;
        MCSDataReaderLog(@"%@: <%p>.close;\n", NSStringFromClass(self.class), self);
    } @catch (__unused NSException *exception) {
        
    }
}

#pragma mark - MCSDownloadTaskDelegate

- (void)downloadTask:(NSURLSessionTask *)task didReceiveResponse:(NSHTTPURLResponse *)response {
    dispatch_barrier_sync(MCSDataReaderQueue(), ^{
        if ( _isClosed || _resource == nil ) {
            [self _close];
            return;
        }

        _content = [_resource partialContentForNetworkDataReaderWithProxyURL:_request.URL response:response];
        if ( _content == nil ) {
            [self _onError:[NSError mcs_responseUnavailable:task.currentRequest.URL request:_request response:response]];
            return;
        }
        NSRange range = _request.mcs_range;
        if ( range.location == NSNotFound ) range.location = 0;
        range.length = (NSUInteger)response.expectedContentLength;
        
        if ( range.length == NSURLResponseUnknownLength ) {
            [self _onError:[NSError mcs_errorWithCode:MCSResponseUnavailableError userInfo:@{
                MCSErrorUserInfoRequestKey : _request,
                NSLocalizedDescriptionKey : [NSString stringWithFormat:@"请求 %@ 返回的 ContentLength 无效! ", _request],
            }]];
            return;
        }
        
        _range = range;
        NSString *filePath = [_resource filePathOfContent:_content];
        MCSContentNetworkReadwrite *readwrite = [MCSContentNetworkReadwrite readerWithPath:filePath];
        __weak typeof(self) _self = self;
        readwrite.onErrorExecuteBlock = ^(NSError * _Nonnull error) {
            __strong typeof(_self) self = _self;
            if ( !self ) return;
            dispatch_barrier_sync(MCSDataReaderQueue(), ^{
                [self _onError:error];
            });
        };
        
        __auto_type resource = _resource;
        __auto_type content = _content;
        readwrite.writeFinishedExecuteBlock = ^{
            [resource didEndReadwriteContent:content];
        };
        readwrite.didWriteDataExecuteBlock = ^(NSUInteger length) {
            [resource didWriteDataForContent:content length:length];
        };
        
        _reader = readwrite;
        if ( _reader == nil ) {
            [self _onError:[NSError mcs_fileNotExistErrorWithUserInfo:@{
                MCSErrorUserInfoResourceKey : _resource,
                MCSErrorUserInfoRangeKey : [NSValue valueWithRange:_range]
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
    dispatch_barrier_sync(MCSDataReaderQueue(), ^{
        @try {
            if ( _isClosed || _resource == nil ) {
                [task cancel];
                [self _close];
                return;
            }
            
            MCSContentNetworkReadwrite *reader = _reader;
            [reader appendData:data];
            
            NSUInteger length = data.length;
            _availableLength += length;
            dispatch_async(MCSDelegateQueue(), ^{
                [self->_delegate reader:self hasAvailableDataWithLength:length];
            });
        } @catch (NSException *exception) {
            [self _onError:[NSError mcs_exception:exception]];
        }
    });
}

- (void)downloadTask:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    dispatch_barrier_sync(MCSDataReaderQueue(), ^{
       if ( _isClosed )
           return;
        
        if ( error != nil && error.code != NSURLErrorCancelled ) {
            [self _onError:error];
        }
        //    else {
        //        // finished download
        //    }
        
        MCSContentNetworkReadwrite *reader = self->_reader;
        [reader completeDownload];
    });
}

@end
