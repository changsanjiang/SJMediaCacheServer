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

@interface SJNetworkReader ()<SJDownloadTaskDelegate>
@property (nonatomic, strong) SJDataRequest *request;
@property (nonatomic, strong) NSURLSessionTask *task;

@property (nonatomic, strong) NSFileHandle *reader;
@property (nonatomic, strong) NSFileHandle *writer;

@property (nonatomic, strong) SJResourcePartialContent *content;
@property (nonatomic) UInt64 downloadedLength;
@property (nonatomic) UInt64 offset;
@property (nonatomic) BOOL isClosed;
@property (nonatomic, strong) NSError *error;
@end

@implementation SJNetworkReader
- (instancetype)initWithRequest:(SJDataRequest *)request {
    self = [super init];
    if ( self ) {
        _request = request;
    }
    return self;
}

- (void)prepare {
    NSMutableURLRequest *request = [NSMutableURLRequest.alloc initWithURL:_request.URL];
    [request setAllHTTPHeaderFields:_request.headers];
    [request setValue:[NSString stringWithFormat:@"bytes=%lu-%lu", (unsigned long)_request.range.location, (unsigned long)_request.range.length - 1] forHTTPHeaderField:@"Range"];
    self.task = [SJDownload.shared downloadWithRequest:request delegate:self];
}

- (nullable NSData *)readDataOfLength:(NSUInteger)lengthParam {
    if ( self.downloadedLength > self.offset ) {
        @try {
            UInt64 length = MIN(lengthParam, self.downloadedLength - self.offset);
            if ( length > 0 ) {
                NSData *data = [self.reader readDataOfLength:length];
                self.offset += length;
                return data;
            }
        } @catch (NSException *exception) {
            [self _onError:[SJError errorForException:exception]];
        }
    }
    return nil;
}

- (void)close {
    self.isClosed = YES;
    [self.task cancel];
}

#pragma mark -

- (void)downloadTask:(NSURLSessionTask *)task didReceiveResponse:(NSURLResponse *)response {
    SJResource *resource = nil;
    _content = [resource newContentWithOffset:_request.range.location];
    NSString *filePath = [resource filePathWithContent:_content];
    _reader = [NSFileHandle fileHandleForReadingAtPath:filePath];
    _writer = [NSFileHandle fileHandleForWritingAtPath:filePath];
}

- (void)downloadTask:(NSURLSessionTask *)task didReceiveData:(NSData *)data {
    @try {
        [_writer writeData:data];
        self.downloadedLength += data.length;
        [self.content updateLength:self.downloadedLength];
        [self.delegate readerHasAvailableData:self];
    } @catch (NSException *exception) {
        [self _onError:[SJError errorForException:exception]];
    }
}

- (void)downloadTask:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if ( self.isClosed ) {
        return;
    }
    
    if ( error != nil && error.code != NSURLErrorCancelled ) {
        [self _onError:error];
    }
    else {
        // finished
    }
}

- (void)_onError:(NSError *)error {
    [self.delegate reader:self anErrorOccurred:error];
}
@end
