//
//  MCSData.m
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/7/7.
//

#import "MCSData.h"

@implementation MCSData {
    dispatch_semaphore_t _semaphore;
    NSMutableData *_m;
    NSError *_error;
    void(^_willPerformHTTPRedirection)(NSHTTPURLResponse *response, NSURLRequest *newRequest);
}

+ (NSData *)dataWithContentsOfRequest:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority error:(NSError **)error willPerformHTTPRedirection:(void(^_Nullable)(NSHTTPURLResponse *response, NSURLRequest *newRequest))block {
    MCSData *data = [MCSData.alloc initWithContentsOfRequest:request networkTaskPriority:networkTaskPriority error:error willPerformHTTPRedirection:block];
    return data != nil ? data->_m : nil;
}

- (instancetype)initWithContentsOfRequest:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority error:(NSError **)error willPerformHTTPRedirection:(void(^)(NSHTTPURLResponse *response, NSURLRequest *newRequest))block {
    self = [super init];
    if ( self ) {
        _willPerformHTTPRedirection = block;
        _m = NSMutableData.data;
        [MCSDownload.shared downloadWithRequest:request priority:networkTaskPriority delegate:self];
        _semaphore = dispatch_semaphore_create(0);
        dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
        if ( _error != nil && error != NULL ) *error = _error;
    }
    return self;
}

- (void)downloadTask:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request {
    if ( _willPerformHTTPRedirection != nil ) _willPerformHTTPRedirection(response, request);
}

- (void)downloadTask:(NSURLSessionTask *)task didReceiveResponse:(NSURLResponse *)response { }

- (void)downloadTask:(NSURLSessionTask *)task didReceiveData:(NSData *)data {
    [_m appendData:data];
}

- (void)downloadTask:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    _error = error;
    dispatch_semaphore_signal(_semaphore);
}
@end
