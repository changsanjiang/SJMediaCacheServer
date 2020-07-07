//
//  MCSHLSAESKeyDataReader.m
//  SJMediaCacheServer
//
//  Created by 畅三江 on 2020/6/23.
//

#import "MCSHLSAESKeyDataReader.h"
#import "MCSHLSResource.h"
#import "MCSFileManager.h"
#import "MCSError.h"
#import "MCSResourceResponse.h"
#import "MCSLogger.h"
#import "MCSData.h"
#import "MCSUtils.h"
#import "MCSURLRecognizer.h"

@interface MCSHLSAESKeyDataReader ()<NSLocking> {
    dispatch_semaphore_t _semaphore;
}
@property (nonatomic, weak) MCSHLSResource *resource;
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic) float networkTaskPriority;

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isClosed;

@property (nonatomic) NSUInteger availableLength;
@property (nonatomic) NSUInteger offset;
@property (nonatomic, strong, nullable) NSFileHandle *reader;
@end

@implementation MCSHLSAESKeyDataReader
@synthesize delegate = _delegate;
@synthesize delegateQueue = _delegateQueue;
@synthesize isDone = _isDone;
@synthesize response = _response;
@synthesize isPrepared = _isPrepared;

- (instancetype)initWithResource:(MCSHLSResource *)resource request:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority delegate:(id<MCSResourceDataReaderDelegate>)delegate delegateQueue:(dispatch_queue_t)queue {
    self = [super init];
    if ( self ) {
        _resource = resource;
        _request = request;
        _networkTaskPriority = networkTaskPriority;
        _delegate = delegate;
        _delegateQueue = queue;
        _semaphore = dispatch_semaphore_create(1);
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { URL: %@\n };", NSStringFromClass(self.class), self, _request.URL];
}

- (void)prepare {
    [self lock];
    @try {
        if ( _isClosed || _isCalledPrepare )
            return;
        
        MCSLog(@"%@: <%p>.prepare { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);
        
        _isCalledPrepare = YES;
        
        NSString *name = [MCSURLRecognizer.shared nameWithUrl:_request.URL.absoluteString extension:MCSHLSAESKeyFileExtension];
        NSString *filePath = [MCSFileManager hls_AESKeyFilePathInResource:_resource.name AESKeyName:name];
        
        if ( [MCSFileManager fileExistsAtPath:filePath] ) {
            // go to read the content
            [self _prepare:filePath];
            return;
        }
        
        MCSLog(@"%@: <%p>.request { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);
        
        // download the content
        
        NSError *error = nil;
        NSData *data = [MCSData dataWithContentsOfRequest:[_request mcs_requestWithHTTPAdditionalHeaders:[_resource.configuration HTTPAdditionalHeadersForDataRequestsOfType:MCSDataTypeHLSAESKey]] networkTaskPriority:_networkTaskPriority error:&error];
        if ( _isClosed )
            return;
         
        [MCSFileManager lock];
        if ( ![MCSFileManager fileExistsAtPath:filePath] ) {
            if ( ![data writeToFile:filePath atomically:YES] ) {
                [MCSFileManager unlock];
                [self _onError:[NSError mcs_HLSAESKeyWriteFailedError:_request.URL]];
                return;
            }
        }
        [MCSFileManager unlock];
        
        [self _prepare:filePath];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (nullable NSData *)readDataOfLength:(NSUInteger)lengthParam {
    [self lock];
    @try {
        if ( _isClosed || _isDone || !_isPrepared )
            return nil;
        
        NSData *data = nil;
        
        if ( _offset < _availableLength ) {
            NSUInteger length = MIN(lengthParam, _availableLength - _offset);
            if ( length > 0 ) {
                data = [_reader readDataOfLength:length];
                _offset += data.length;
                _isDone = _offset == _response.totalLength;
                MCSLog(@"%@: <%p>.read { offset: %lu, length: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)_offset, (unsigned long)data.length);
            }
        }
        
        return data;
    } @catch (NSException *exception) {
        [self _onError:[NSError mcs_exception:exception]];
    } @finally {
#ifdef DEBUG
        if ( _isDone ) {
            MCSLog(@"%@: <%p>.done { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);
        }
#endif
        [self unlock];
    }
}

- (void)close {
    [self lock];
    [self _close];
    [self unlock];
}

#pragma mark -

- (BOOL)isPrepared {
    [self lock];
    @try {
        return _isPrepared;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (BOOL)isDone {
    [self lock];
    @try {
        return _isDone;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (id<MCSResourceResponse>)response {
    [self lock];
    @try {
        return _response;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

#pragma mark -

- (void)_onError:(NSError *)error {
    [self _close];
    
    dispatch_async(_delegateQueue, ^{
        [self.delegate reader:self anErrorOccurred:error];
    });
}

- (void)_prepare:(NSString *)filePath {
    _availableLength = [MCSFileManager fileSizeAtPath:filePath];
    _response = [MCSResourceResponse.alloc initWithServer:@"localhost" contentType:@"application/octet-stream" totalLength:_availableLength];
    _reader = [NSFileHandle fileHandleForReadingAtPath:filePath];

    if ( _reader == nil ) {
        [self _onError:[NSError mcs_fileNotExistError:_request.URL]];
        return;
    }

    _isPrepared = YES;
    dispatch_async(_delegateQueue, ^{
        [self.delegate readerPrepareDidFinish:self];
    });
}

- (void)_close {
    if ( _isClosed )
        return;
    
    @try {
        [_reader closeFile];
        _reader = nil;
        _isClosed = YES;
        
        MCSLog(@"%@: <%p>.close;\n", NSStringFromClass(self.class), self);
    } @catch (__unused NSException *exception) {
        
    }
}

#pragma mark -

- (void)lock {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
}

- (void)unlock {
    dispatch_semaphore_signal(_semaphore);
}

@end
