//
//  SJNetworkReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJNetworkReader.h"
#import "SJDownload.h"

@interface SJNetworkReader ()<SJDownloadTaskDelegate>
@property (nonatomic, strong) SJDataRequest *request;
@property (nonatomic, strong) NSURLSessionTask *task;

@property (nonatomic, strong) NSFileHandle *reader;
@property (nonatomic, strong) NSFileHandle *writer;
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

- (nullable NSData *)readDataOfLength:(NSUInteger)length {
    return nil;
}

- (void)close {
    
}

#pragma mark -

- (void)downloadTask:(NSURLSessionTask *)task didReceiveResponse:(NSURLResponse *)response {
    
}

- (void)downloadTask:(NSURLSessionTask *)task didReceiveData:(NSData *)data {
    
}

- (void)downloadTask:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
}
@end
