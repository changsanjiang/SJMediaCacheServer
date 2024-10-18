//
//  SJDataDownload.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDownload.h"
#import "MCSConsts.h"
#import "MCSError.h"
#import "MCSUtils.h"
#import "MCSLogger.h"
#import "NSURLRequest+MCS.h"

@interface NSURLSessionTask (MCSDownloadExtended)<MCSDownloadTask>

@end

@interface MCSDownload () <NSURLSessionDataDelegate> {
    NSURLSession *mSession;
    NSOperationQueue *mSessionDelegateQueue;
    NSURLSessionConfiguration *mSessionConfiguration;
    NSMutableDictionary<NSNumber *, NSError *> *mErrorDictionary;
    NSMutableDictionary<NSNumber *, id<MCSDownloadTaskDelegate>> *mDelegateDictionary;
    UIBackgroundTaskIdentifier mBackgroundTaskIdentifier;
    id<MCSDownloadResponse>  _Nullable (^mDefaultResponseHandler)(NSURLSessionTask *task, NSURLResponse * _Nonnull res);
}
@end

@implementation MCSDownload

+ (instancetype)shared {
    static MCSDownload *obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[self alloc] init];
    });
    return obj;
}

- (instancetype)init {
    if (self = [super init]) {
        _timeoutInterval = 30.0f;
        mBackgroundTaskIdentifier = UIBackgroundTaskInvalid;
        mErrorDictionary = [NSMutableDictionary dictionary];
        mDelegateDictionary = [NSMutableDictionary dictionary];
        mSessionDelegateQueue = [[NSOperationQueue alloc] init];
        mSessionDelegateQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        mSessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        mSessionConfiguration.timeoutIntervalForRequest = _timeoutInterval;
        mSessionConfiguration.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
        mSession = [NSURLSession sessionWithConfiguration:mSessionConfiguration delegate:self delegateQueue:mSessionDelegateQueue];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:[UIApplication sharedApplication]];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:[UIApplication sharedApplication]];
        
        mDefaultResponseHandler = ^id<MCSDownloadResponse> _Nullable (NSURLSessionTask *task, NSURLResponse *response) {
            if ( ![response isKindOfClass:NSHTTPURLResponse.class] ) return nil;
            NSHTTPURLResponse *res = (NSHTTPURLResponse *)response;
            MCSResponseContentRange contentRange = MCSResponseGetContentRange(res);
            if ( MCSResponseRangeIsUndefined(contentRange) ) return nil;
            NSRange range = MCSResponseRange(contentRange);
            NSUInteger totalLength = contentRange.totalLength;

            NSInteger statusCode = res.statusCode;
            NSString *_Nullable contentType = MCSResponseGetContentType(res);
            NSString *_Nullable pathExtension = MCSSuggestedPathExtension(res);
            return [MCSDownloadResponse.alloc initWithOriginalRequest:task.originalRequest currentRequest:task.currentRequest statusCode:statusCode pathExtension:pathExtension totalLength:totalLength range:range contentType:contentType];
        };
        _responseHandler = mDefaultResponseHandler;
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setResponseHandler:(id<MCSDownloadResponse>  _Nullable (^)(NSURLSessionTask * _Nonnull, NSURLResponse * _Nonnull))responseHandler {
    _responseHandler = responseHandler ?: mDefaultResponseHandler;
}

#pragma mark - mark

- (nullable id<MCSDownloadTask>)downloadWithRequest:(NSURLRequest *)request priority:(float)priority delegate:(id<MCSDownloadTaskDelegate>)delegate {
    if ( request == nil ) return nil;
    
    NSMutableURLRequest *req = [request mutableCopy];
    req.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    req.timeoutInterval = _timeoutInterval;
    __auto_type requestHandler = _requestHandler;
    if ( requestHandler != nil ) req = requestHandler(req);
    
    NSURLSessionTask *task = [mSession dataTaskWithRequest:req];
    @synchronized (self) { mDelegateDictionary[@(task.taskIdentifier)] = delegate; }
    task.priority = priority;
    [task resume];
    
    MCSDownloaderDebugLog(@"%@: <%p>.downloadWithRequest { task: %lu, request: %@ };\n", NSStringFromClass(self.class), self, (unsigned long)task.taskIdentifier, [req mcs_description]);
    return task;
}

- (void)customSessionConfig:(void (^)(NSURLSessionConfiguration * _Nonnull))config {
    config(mSession.configuration);
}
  
#pragma mark - mark

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    id<MCSDownloadTaskDelegate> delegate;
    @synchronized (self) { delegate = mDelegateDictionary[@(task.taskIdentifier)]; }
    [delegate downloadTask:task willPerformHTTPRedirectionWithNewRequest:request];
    completionHandler(request);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(__kindof NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    MCSDownloaderDebugLog(@"%@: <%p>.didReceiveResponse { task: %lu, response: %@ };\n", NSStringFromClass(self.class), self, (unsigned long)task.taskIdentifier, response);
    
    NSNumber *key = @(task.taskIdentifier);
    id<MCSDownloadResponse> _Nullable downloadRes = self.responseHandler(task, response);
    if ( downloadRes == nil ) {
        NSHTTPURLResponse *httpRes = [response isKindOfClass:NSHTTPURLResponse.class] ? response : nil;
        NSError *error = [NSError mcs_errorWithCode:MCSInvalidResponseError userInfo:@{
            MCSErrorUserInfoObjectKey : response,
            MCSErrorUserInfoReasonKey : [NSString stringWithFormat:@"Invalid response: %@; httpRes.statusCode=%ld, httpRes.allHeaderFields=%@", response, httpRes.statusCode, httpRes.allHeaderFields]
        }];
        @synchronized (self) { mErrorDictionary[key] = error; }
        completionHandler(NSURLSessionResponseCancel);
        return;
    }
    
    id<MCSDownloadTaskDelegate> delegate;
    @synchronized (self) { delegate = mDelegateDictionary[key]; }
    [delegate downloadTask:task didReceiveResponse:downloadRes];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    MCSDownloaderDebugLog(@"%@: <%p>.didReceiveData { task: %lu, dataLength: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)dataTask.taskIdentifier, (unsigned long)data.length);
    id<MCSDownloadTaskDelegate> delegate;
    @synchronized (self) { delegate = mDelegateDictionary[@(dataTask.taskIdentifier)]; }
    __auto_type receivedDataEncoder = _receivedDataEncoder;
    if ( receivedDataEncoder != nil ) {
        NSData *newData = receivedDataEncoder(dataTask.currentRequest, (NSUInteger)(dataTask.countOfBytesReceived - data.length), data);
        if ( newData.length != data.length ) {
            @throw [NSException exceptionWithName:NSGenericException 
                                           reason:@"The length of the encoded data must be the same as the original data."
                                         userInfo:nil];
        }
        data = newData;
    }
    [delegate downloadTask:dataTask didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics API_AVAILABLE(ios(10.0)) {
    __auto_type block = _didFinishCollectingMetrics;
    if ( block != nil) block(session, task, metrics);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)errorParam {
    MCSDownloaderDebugLog(@"%@: <%p>.didCompleteWithError { task: %lu, error: %@ };\n", NSStringFromClass(self.class), self, (unsigned long)task.taskIdentifier, errorParam);
    NSNumber *key = @(task.taskIdentifier);
    NSError *error;
    id<MCSDownloadTaskDelegate> delegate;
    @synchronized (self) {
        delegate = mDelegateDictionary[key];
        error = mErrorDictionary[key] ?: errorParam;
        
        mDelegateDictionary[key] = nil;
        mErrorDictionary[key] = nil;
    }
    
    [delegate downloadTask:task didCompleteWithError:error];
}
  
#pragma mark - Background Task

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    // begin background task
    if ( mBackgroundTaskIdentifier != UIBackgroundTaskInvalid ) {
        mBackgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [UIApplication.sharedApplication endBackgroundTask:self->mBackgroundTaskIdentifier];
            self->mBackgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    // end background task
    if ( mBackgroundTaskIdentifier != UIBackgroundTaskInvalid ) {
        [UIApplication.sharedApplication endBackgroundTask:mBackgroundTaskIdentifier];
        mBackgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
}
@end


@implementation MCSDownloadResponse
- (instancetype)initWithOriginalRequest:(NSURLRequest *)originalRequest
                         currentRequest:(NSURLRequest *)currentRequest
                             statusCode:(NSInteger)statusCode
                          pathExtension:(NSString *_Nullable)pathExtension
                            totalLength:(NSUInteger)totalLength
                                  range:(NSRange)range
                            contentType:(NSString *_Nullable)contentType {
    self = [super initWithTotalLength:totalLength range:range contentType:contentType];
    _originalRequest = originalRequest;
    _currentRequest = currentRequest;
    _statusCode = statusCode;
    _pathExtension = pathExtension;
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { originalRequest: %@, currentRequest: %@, statusCode: %ld, pathExtension: %@, totalLength: %lu, range: %@, contentType: %@ };\n", NSStringFromClass(self.class), self, _originalRequest, _currentRequest, _statusCode, _pathExtension, (unsigned long)self.totalLength, NSStringFromRange(self.range), self.contentType];
}
@end
