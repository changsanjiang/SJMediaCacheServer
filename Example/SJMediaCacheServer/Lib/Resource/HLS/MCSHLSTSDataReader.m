//
//  MCSHLSTSDataReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/10.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSTSDataReader.h"
#import "MCSHLSResource+MCSPrivate.h"
#import "MCSLogger.h"
#import "MCSHLSResource.h"
#import "MCSResourceSubclass.h"
#import "MCSResourceNetworkDataReader.h"
#import "MCSResourceFileDataReader.h"
#import "MCSDownload.h"
#import "MCSUtils.h"

@interface MCSHLSTSDataReader ()<MCSDownloadTaskDelegate, NSLocking> {
    NSRecursiveLock *_lock;
}
@property (nonatomic, weak, nullable) MCSHLSResource *resource;
@property (nonatomic, strong) NSURLRequest *request;

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isClosed;
@property (nonatomic) BOOL isDone;

@property (nonatomic, strong, nullable) MCSResourcePartialContent *content;
@property (nonatomic) NSUInteger downloadedLength;
@property (nonatomic) NSUInteger offset;

@property (nonatomic, strong, nullable) NSURLSessionTask *task;
@property (nonatomic, strong, nullable) NSFileHandle *reader;
@property (nonatomic, strong, nullable) NSFileHandle *writer;
@end

@implementation MCSHLSTSDataReader
@synthesize delegate = _delegate;

- (instancetype)initWithResource:(MCSHLSResource *)resource request:(NSURLRequest *)request {
    self = [super init];
    if ( self ) {
        _resource = resource;
        _request = request;
        _lock = NSRecursiveLock.alloc.init;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { URL: %@\n };", NSStringFromClass(self.class), self, _request.URL];
}

- (void)prepare {
    if ( _isClosed || _isCalledPrepare )
        return;
    
    MCSLog(@"%@: <%p>.prepare { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);

    _isCalledPrepare = YES;
    
    _content = [_resource contentForTsURL:_request.URL];
    if ( _content != nil ) {
        [self _prepare];
    }
    else {
        _task = [MCSDownload.shared downloadWithRequest:_request delegate:self];
    }
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    [self lock];
    @try {

#warning next ..... mmm
        
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)close {
    [_content readWrite_release];
}

- (void)_prepare {
    [_content readWrite_retain];
    NSString *filepath = [_resource filePathOfContent:_content];
    _reader = [NSFileHandle fileHandleForReadingAtPath:filepath];
    _response = [MCSResourceResponse.alloc initWithServer:@"localhost" contentType:_content.tsContentType totalLength:_content.tsTotalLength];
    [self.delegate readerPrepareDidFinish:self];
}

#pragma mark -

- (void)downloadTask:(NSURLSessionTask *)task didReceiveResponse:(NSHTTPURLResponse *)response {
    [self lock];
    @try {
        if ( _isClosed )
            return;
        NSString *contentType = MCSGetResponseContentType(response);
        NSUInteger totalLength = MCSGetResponseContentLength(response);
        _content = [_resource createContentWithTsURL:_request.URL tsContentType:contentType tsTotalLength:totalLength];
        [self _prepare];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)downloadTask:(NSURLSessionTask *)task didReceiveData:(NSData *)data {
    
}

- (void)downloadTask:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
}

#pragma mark -

- (void)lock {
    [_lock lock];
}

- (void)unlock {
    [_lock unlock];
}
@end
