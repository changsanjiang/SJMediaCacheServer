//
//  MCSData.m
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/7/7.
//

#import "MCSContents.h"
#import "MCSDownload.h"

@interface MCSContents()<MCSDownloadTask, MCSDownloadTaskDelegate>

@end

@implementation MCSContents {
    id _Nullable mStringSelf;
    id<MCSDownloadTask> mTask;
    NSMutableData *mData;
    void(^mWillPerformHTTPRedirection)(NSURLRequest *newRequest);
    void(^mCompletionHandler)(NSData *_Nullable data, NSError *_Nullable error);
}

+ (id<MCSDownloadTask>)request:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority willPerformHTTPRedirection:(void(^_Nullable)(NSURLRequest *newRequest))block completion:(void(^)(NSData *_Nullable data, NSError *_Nullable error))completionHandler {
    MCSContents *cts = [MCSContents.alloc initWithWillPerformHTTPRedirection:block completion:completionHandler];
    [cts startWithRequest:request networkTaskPriority:networkTaskPriority];
    return cts;
}

- (instancetype)initWithWillPerformHTTPRedirection:(void(^_Nullable)(NSURLRequest *newRequest))block completion:(void(^)(NSData *_Nullable data, NSError *_Nullable error))completionHandler {
    self = [super init];
    if ( self ) {
        mWillPerformHTTPRedirection = block;
        mCompletionHandler = completionHandler;
        mData = NSMutableData.data;
    }
    return self;
}

- (void)startWithRequest:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority {
    mStringSelf = self;
    mTask = [MCSDownload.shared downloadWithRequest:request priority:networkTaskPriority delegate:self];
}

- (void)cancel {
    [mTask cancel];
}

#pragma mark - MCSDownloadTaskDelegate

- (void)downloadTask:(id<MCSDownloadTask>)task willPerformHTTPRedirectionWithNewRequest:(NSURLRequest *)request {
    if ( mWillPerformHTTPRedirection != nil ) mWillPerformHTTPRedirection(request);
}

- (void)downloadTask:(id<MCSDownloadTask>)task didReceiveResponse:(id<MCSDownloadResponse>)response { }

- (void)downloadTask:(id<MCSDownloadTask>)task didReceiveData:(NSData *)data {
    [mData appendData:data];
}

- (void)downloadTask:(id<MCSDownloadTask>)task didCompleteWithError:(NSError *)error {
    mCompletionHandler(error == nil ? mData : nil, error);
    mStringSelf = nil;
}
@end
