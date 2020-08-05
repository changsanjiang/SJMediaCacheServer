//
//  MCSHLSTSDataReader.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/10.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSTSDataReader.h"
#import "MCSLogger.h"
#import "MCSHLSResource.h"
#import "MCSResourceFileDataReader.h"
#import "MCSDownload.h"
#import "MCSUtils.h"
#import "MCSError.h"
#import "MCSFileManager.h"
#import "MCSResourceResponse.h"
#import "NSFileHandle+MCS.h"
#import "MCSQueue.h"

@interface MCSHLSTSDataReader ()<MCSDownloadTaskDelegate>
@property (nonatomic, weak, nullable) MCSHLSResource *resource;
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong, nullable) id<MCSResourceResponse> response;

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isPrepared;
@property (nonatomic) BOOL isClosed;
@property (nonatomic) BOOL isDone;
@property (nonatomic) BOOL isSought;

@property (nonatomic, strong, nullable) MCSResourcePartialContent *content;
@property (nonatomic) NSUInteger availableLength;
@property (nonatomic) NSUInteger offset;

@property (nonatomic, strong, nullable) NSURLSessionTask *task;
@property (nonatomic, strong, nullable) NSFileHandle *reader;
@property (nonatomic, strong, nullable) NSFileHandle *writer;
@property (nonatomic) float networkTaskPriority;
@end

@implementation MCSHLSTSDataReader
@synthesize delegate = _delegate;
@synthesize range = _range;

- (instancetype)initWithResource:(MCSHLSResource *)resource request:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority delegate:(id<MCSResourceDataReaderDelegate>)delegate {
    self = [super init];
    if ( self ) {
        _networkTaskPriority = networkTaskPriority;
        _resource = resource;
        _request = request;
        _delegate = delegate;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { URL: %@\n };", NSStringFromClass(self.class), self, _request.URL];
}

- (void)prepare {
    dispatch_barrier_sync(MCSHLSTsDataReaderQueue(), ^{
        if ( _isClosed || _isCalledPrepare )
            return;
        
        MCSDataReaderLog(@"%@: <%p>.prepare { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);

        _isCalledPrepare = YES;
        
        _content = [_resource contentForTsURL:_request.URL];
        
        if ( _content != nil ) {
            // go to read the content
            [self _prepare];
            return;
        }
        
        MCSDataReaderLog(@"%@: <%p>.request { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);
        
        // download the content
        _task = [MCSDownload.shared downloadWithRequest:[_request mcs_requestWithHTTPAdditionalHeaders:[_resource.configuration HTTPAdditionalHeadersForDataRequestsOfType:MCSDataTypeHLSTs]] priority:_networkTaskPriority delegate:self];
    });
}

- (NSData *)readDataOfLength:(NSUInteger)lengthParam {
    __block NSData *data = nil;
    dispatch_barrier_sync(MCSHLSTsDataReaderQueue(), ^{
        @try {
            if ( _isClosed || _isDone || !_isPrepared )
                return;
            
            if ( _isSought ) {
                _isSought = NO;
                NSError *error = nil;
                if ( ![_reader mcs_seekToFileOffset:_offset error:&error] ) {
                    [self _onError:error];
                    return;
                }
            }
            
            if ( _offset < _availableLength ) {
                NSUInteger length = MIN(lengthParam, _availableLength - _offset);
                if ( length > 0 ) {
                    data = [_reader readDataOfLength:length];
                    MCSDataReaderLog(@"%@: <%p>.read { offset: %lu, length: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)_offset, (unsigned long)data.length);
                    _offset += data.length;
                    _isDone = (_offset == _response.totalLength);
                }
            }
            
#ifdef DEBUG
            if ( _isDone ) {
                MCSDataReaderLog(@"%@: <%p>.done { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);
            }
#endif
        } @catch (NSException *exception) {
            [self _onError:[NSError mcs_exception:exception]];
        }
    });
    return data;
}

- (BOOL)seekToOffset:(NSUInteger)offset {
    __block BOOL result = NO;
    dispatch_barrier_sync(MCSHLSTsDataReaderQueue(), ^{
        if ( _isClosed || !_isPrepared || offset > _availableLength )
            return;
        
        if ( offset != _offset ) {
            _isSought = YES;
            _offset = offset;
            _isDone = (_offset == _response.totalLength);
        }
        result = YES;
    });
    return result;
}

- (void)close {
    dispatch_barrier_sync(MCSHLSTsDataReaderQueue(), ^{
        [self _close];
    });
}

#pragma mark -

- (NSRange)range {
    __block NSRange range = NSMakeRange(0, 0);
    dispatch_sync(MCSHLSTsDataReaderQueue(), ^{
        range = _range;
    });
    return range;
}

- (NSUInteger)availableLength {
    __block NSUInteger availableLength = 0;
    dispatch_sync(MCSHLSTsDataReaderQueue(), ^{
        availableLength = _availableLength;
    });
    return availableLength;
}

- (NSUInteger)offset {
    __block NSUInteger offset = 0;
    dispatch_sync(MCSHLSTsDataReaderQueue(), ^{
        offset = _offset;
    });
    return offset;
}

- (BOOL)isPrepared {
    __block BOOL isPrepared = NO;
    dispatch_sync(MCSHLSTsDataReaderQueue(), ^{
        isPrepared = _isPrepared;
    });
    return isPrepared;
}

- (BOOL)isDone {
    __block BOOL isDone = NO;
    dispatch_sync(MCSHLSTsDataReaderQueue(), ^{
        isDone = _isDone;
    });
    return isDone;
}

- (id<MCSResourceResponse>)response {
    __block id<MCSResourceResponse> response = nil;
    dispatch_sync(MCSHLSTsDataReaderQueue(), ^{
        response = _response;
    });
    return response;
}

#pragma mark - MCSDownloadTaskDelegate

- (void)downloadTask:(NSURLSessionTask *)task didReceiveResponse:(NSHTTPURLResponse *)response {
    dispatch_barrier_sync(MCSHLSTsDataReaderQueue(), ^{
        if ( _isClosed )
            return;
        
        NSString *contentType = MCSGetResponseContentType(response);
        [_resource updateTsContentType:contentType];
        _content = [_resource createContentWithTsURL:_request.URL totalLength:(NSUInteger)response.expectedContentLength];
        [self _prepare];
    });
}

- (void)downloadTask:(NSURLSessionTask *)task didReceiveData:(NSData *)data {
    dispatch_barrier_sync(MCSHLSTsDataReaderQueue(), ^{
        @try {
            if ( _isClosed )
                return;
            
            if ( _resource == nil ) {
                [self _close];
                return;
            }
            
            [_writer writeData:data];
            NSUInteger length = data.length;
            _availableLength += length;
            [_content didWriteDataWithLength:length];
            dispatch_async(MCSDelegateQueue(), ^{
                [self->_delegate reader:self hasAvailableDataWithLength:length];
            });
        } @catch (NSException *exception) {
            [self _onError:[NSError mcs_exception:exception]];
            
        }
    });
}

- (void)downloadTask:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    dispatch_barrier_sync(MCSHLSTsDataReaderQueue(), ^{
        if ( _isClosed )
            return;
        
        if ( error != nil && error.code != NSURLErrorCancelled ) {
            [self _onError:error];
        }
        else {
            // finished download
        }
    });
}

#pragma mark -

- (void)_onError:(NSError *)error {
    [self _close];
    
    dispatch_async(MCSDelegateQueue(), ^{
        [self->_delegate reader:self anErrorOccurred:error];
    });
}

- (void)_prepare {
    [_content readWrite_retain];
    NSString *filePath = [_resource filePathOfContent:_content];
    NSUInteger availableLength = [MCSFileManager fileSizeAtPath:filePath];
    _range = NSMakeRange(0, _content.tsTotalLength);
    _reader = [NSFileHandle fileHandleForReadingAtPath:filePath];
    _writer = [NSFileHandle fileHandleForWritingAtPath:filePath];
    _response = [MCSResourceResponse.alloc initWithServer:@"localhost" contentType:_resource.TsContentType totalLength:_content.tsTotalLength];
    _availableLength = availableLength;
        
    if ( _reader == nil || _writer == nil ) {
        [self _onError:[NSError mcs_fileNotExistError:nil]];
        return;
    }

    _isPrepared = YES;
    
    dispatch_async(MCSDelegateQueue(), ^{
        [self->_delegate readerPrepareDidFinish:self];
        
        if ( availableLength != 0 ) {
            [self->_delegate reader:self hasAvailableDataWithLength:availableLength];
        }
    });
}

- (void)_close {
    if ( _isClosed )
        return;
    
    @try {
        if ( _task.state == NSURLSessionTaskStateRunning ) [_task cancel];
        _task = nil;
        [_writer synchronizeFile];
        [_writer closeFile];
        _writer = nil;
        [_reader closeFile];
        _reader = nil;
        [_content readWrite_release];
        _isClosed = YES;
        
        MCSDataReaderLog(@"%@: <%p>.close;\n", NSStringFromClass(self.class), self);
    } @catch (__unused NSException *exception) {
        
    }
}
@end

//
//<NSHTTPURLResponse: 0x6000031fed20> { URL: http://hls.cntv.myalicdn.com/asp/hls/450/0303000a/3/default/bca293257d954934afadfaa96d865172/0.ts } { Status Code: 200, Headers {
//    "Accept-Ranges" =     (
//        bytes
//    );
//    "Access-Control-Allow-Credentials" =     (
//        true
//    );
//    "Access-Control-Allow-Methods" =     (
//        GET
//    );
//    "Access-Control-Allow-Origin" =     (
//        "*"
//    );
//    Age =     (
//        4438779
//    );
//    "Ali-Swift-Global-Savetime" =     (
//        1592187539
//    );
//    Connection =     (
//        "keep-alive"
//    );
//    "Content-Length" =     (
//        791292
//    );
//    "Content-Type" =     (
//        "video/MP2T"
//    );
//    Date =     (
//        "Mon, 15 Jun 2020 02:18:59 GMT"
//    );
//    EagleId =     (
//        65e21b1a15966263187734958e
//    );
//    Etag =     (
//        "\"F7FEE5C1B199B60F3145350FB6C9C311\""
//    );
//    "Last-Modified" =     (
//        "Tue, 27 Aug 2019 03:47:58 GMT"
//    );
//    Server =     (
//        Tengine
//    );
//    "Timing-Allow-Origin" =     (
//        "*"
//    );
//    Via =     (
//        "cache37.l2cm9-2[0,206-0,H], cache18.l2cm9-2[0,0], cache43.l2cn1807[0,206-0,H], cache12.l2cn1807[1,0], cache15.cn1906[0,206-0,H], cache6.cn1906[26,0]"
//    );
//    "X-Cache" =     (
//        "HIT TCP_HIT dirn:8:899603854 mlen:0"
//    );
//    "X-Swift-CacheTime" =     (
//        8640000
//    );
//    "X-Swift-SaveTime" =     (
//        "Mon, 20 Jul 2020 03:34:45 GMT"
//    );
//    cdncip =     (
//        "180.174.11.154"
//    );
//    cdnsip =     (
//        "cache6.cn1906"
//    );
//    "x-oss-cdn-auth" =     (
//        success
//    );
//    "x-oss-hash-crc64ecma" =     (
//        16822164302262876552
//    );
//    "x-oss-meta-access-control-allow-credentials" =     (
//        true
//    );
//    "x-oss-meta-access-control-allow-methods" =     (
//        GET
//    );
//    "x-oss-meta-access-control-allow-origin" =     (
//        "*"
//    );
//    "x-oss-object-type" =     (
//        Normal
//    );
//    "x-oss-request-id" =     (
//        5EE6DA93CF4DC1373876B7D3
//    );
//    "x-oss-server-time" =     (
//        79
//    );
//    "x-oss-storage-class" =     (
//        Standard
//    );
//} }
//
