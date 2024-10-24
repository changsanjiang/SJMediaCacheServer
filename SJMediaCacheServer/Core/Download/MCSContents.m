//
//  MCSData.m
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/7/7.
//

#import "MCSContents.h"
#import "MCSDownload.h"

@interface MCSContents()<MCSDownloadTaskDelegate>

@end

@implementation MCSContents {
    id _Nullable mStringSelf;
    id<MCSDownloadTask> mTask;
    id<MCSDownloadResponse> _Nullable mResponse;
    NSMutableData *mData;
    void(^mCompletionHandler)(id<MCSDownloadTask> task, id<MCSDownloadResponse> _Nullable response, NSData *_Nullable data, NSError *_Nullable error);
}

+ (id<MCSDownloadTask>)request:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority completion:(void(^)(id<MCSDownloadTask> task, id<MCSDownloadResponse> _Nullable response, NSData *_Nullable data, NSError *_Nullable error))completionHandler {
    MCSContents *cts = [MCSContents.alloc initWithCompletion:completionHandler];
    return [cts startWithRequest:request networkTaskPriority:networkTaskPriority];
}

- (instancetype)initWithCompletion:(void(^)(id<MCSDownloadTask> task, id<MCSDownloadResponse> _Nullable response, NSData *_Nullable data, NSError *_Nullable error))completionHandler {
    self = [super init];
    mCompletionHandler = completionHandler;
    return self;
}

- (id<MCSDownloadTask>)startWithRequest:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority {
    mStringSelf = self;
    mData = NSMutableData.data;
    mTask = [MCSDownload.shared downloadWithRequest:request priority:networkTaskPriority delegate:self];
    return mTask;
}

- (void)cancel {
    [mTask cancel];
}

#pragma mark - MCSDownloadTaskDelegate

- (void)downloadTask:(id<MCSDownloadTask>)task willPerformHTTPRedirectionWithNewRequest:(NSURLRequest *)request { }

- (void)downloadTask:(id<MCSDownloadTask>)task didReceiveResponse:(id<MCSDownloadResponse>)response { 
    mResponse = response;
}

- (void)downloadTask:(id<MCSDownloadTask>)task didReceiveData:(NSData *)data {
    [mData appendData:data];
}

- (void)downloadTask:(id<MCSDownloadTask>)task didCompleteWithError:(NSError *)error {
    mCompletionHandler(task, mResponse, error == nil ? mData : nil, error);
    mStringSelf = nil;
}
@end
