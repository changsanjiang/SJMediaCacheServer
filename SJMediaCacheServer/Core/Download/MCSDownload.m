//
//  SJDataDownload.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDownload.h"
#import "MCSError.h"
#import "MCSUtils.h"
#import "MCSQueue.h"
#import "MCSLogger.h"

@interface MCSDownload () <NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSOperationQueue *sessionDelegateQueue;
@property (nonatomic, strong) NSURLSessionConfiguration *sessionConfiguration;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSError *> *errorDictionary;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id<MCSDownloadTaskDelegate>> *delegateDictionary;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property (nonatomic) NSInteger taskCount;
#ifdef DEBUG
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSNumber *> *responseTimeDictionary;
#endif
@end

@implementation MCSDownload
@synthesize taskCount = _taskCount;
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
        _backgroundTask = UIBackgroundTaskInvalid;
        _errorDictionary = [NSMutableDictionary dictionary];
        _delegateDictionary = [NSMutableDictionary dictionary];
        _sessionDelegateQueue = [[NSOperationQueue alloc] init];
        _sessionDelegateQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        _sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _sessionConfiguration.timeoutIntervalForRequest = _timeoutInterval;
        _sessionConfiguration.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
        _session = [NSURLSession sessionWithConfiguration:_sessionConfiguration delegate:self delegateQueue:_sessionDelegateQueue];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:[UIApplication sharedApplication]];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:[UIApplication sharedApplication]];
        

#ifdef DEBUG
        _responseTimeDictionary = [NSMutableDictionary dictionary];
#endif
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)cancelAllDownloadTasks {
    dispatch_barrier_sync(MCSDownloadQueue(), ^{
        _taskCount = 0;
        [_session invalidateAndCancel];
        _session = [NSURLSession sessionWithConfiguration:_sessionConfiguration delegate:self delegateQueue:_sessionDelegateQueue];
    });
}

- (nullable NSURLSessionTask *)downloadWithRequest:(NSURLRequest *)requestParam priority:(float)priority delegate:(id<MCSDownloadTaskDelegate>)delegate {
    NSURLRequest *request = [self _requestWithParam:requestParam];
    if ( request == nil )
        return nil;
    
    NSURLSessionDataTask *task = [_session dataTaskWithRequest:request];
    task.priority = priority;
    [self _setDelegate:delegate forTask:task];
#ifdef DEBUG
    [self _setStartTime:MCSTimerStart() forTask:task];
#endif
    [task resume];
    
    self.taskCount += 1;
    MCSDownloadLog(@"\nTask:<%lu>.resume \n", (unsigned long)task.taskIdentifier);
    MCSDownloadLog(@"TaskCount: %ld\n", (long)self.taskCount);
    
    return task;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    dispatch_barrier_sync(MCSDownloadQueue(), ^{
        completionHandler(request);
    });
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    MCSDownloadLog(@"Task:<%lu>.response, after (%lf) seconds, statusCode: %ld. \n", (unsigned long)task.taskIdentifier, MCSTimerMilePost([self _startTimeForTask:task remove:NO]), (long)response.statusCode);
    MCSDownloadLog(@"TaskCount: %ld\n", (long)self.taskCount);
    
    NSError *error = nil;
    if ( ![response isKindOfClass:NSHTTPURLResponse.class] || response.statusCode > 400 || response.statusCode < 200 ) {
        error = [NSError mcs_responseUnavailable:task.currentRequest.URL request:task.currentRequest response:task.response];
    }
    
    if ( error == nil && response.statusCode == 206 ) {
        NSUInteger contentLength = MCSGetResponseContentLength(response);
        if ( contentLength == 0 ) {
            error = [NSError mcs_responseUnavailable:task.currentRequest.URL request:task.currentRequest response:response];
        }
    }
    
    if ( error == nil && response.statusCode == 206 ) {
        NSRange requestRange = MCSGetRequestNSRange(MCSGetRequestContentRange(task.currentRequest.allHTTPHeaderFields));
        NSRange responseRange = MCSGetResponseNSRange(MCSGetResponseContentRange(response));
        
        if ( !MCSNSRangeIsUndefined(requestRange) ) {
            if ( MCSNSRangeIsUndefined(responseRange) || !NSEqualRanges(requestRange, responseRange) ) {
                error = [NSError mcs_nonsupportContentType:task.currentRequest.URL request:task.currentRequest response:task.response];
            }
        }
    }
    
    if ( error == nil ) {
        id<MCSDownloadTaskDelegate> delegate = [self _delegateForTask:task];
        if ( delegate != nil ) {
            [delegate downloadTask:task didReceiveResponse:response];
            completionHandler(NSURLSessionResponseAllow);
        }
    }
    else {
        [self _setError:error forTask:task];
        completionHandler(NSURLSessionResponseCancel);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)dataParam {
    MCSDownloadLog(@"Task:<%lu>:%lld\t", (unsigned long)dataTask.taskIdentifier, dataTask.countOfBytesReceived);
    
    __auto_type delegate = [self _delegateForTask:dataTask];
    NSData *data = dataParam;
    if ( _dataEncoder != nil )
        data = _dataEncoder(dataTask.currentRequest, (NSUInteger)(dataTask.countOfBytesReceived - dataParam.length), dataParam);
    [delegate downloadTask:dataTask didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)errorParam {
    self.taskCount -= 1;
    NSError *error = [self _errorForTask:task] ?: errorParam;
    MCSDownloadLog(@"\nTask:<%lu>.complete, after (%lf) seconds, error: %@.\n", (unsigned long)task.taskIdentifier, MCSTimerMilePost([self _startTimeForTask:task remove:YES]), error);
    MCSDownloadLog(@"TaskCount: %ld\n\n", (long)self.taskCount);
    
    __auto_type delegate = [self _delegateForTask:task];
    [delegate downloadTask:task didCompleteWithError:error];
    
    [self _setDelegate:nil forTask:task];
    [self _setError:nil forTask:task];
}

#pragma mark -

- (NSURLRequest *)_requestWithParam:(NSURLRequest *)param {
    NSMutableURLRequest *request = [param mutableCopy];
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    request.timeoutInterval = _timeoutInterval;
    
    if ( _requestHandler != nil )
        request = _requestHandler(request);
    
    return request;
}

#pragma mark - Background Task

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    [self _beginBackgroundTaskIfNeeded];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    [self _endBackgroundTaskIfNeeded];
}

- (void)_endBackgroundTaskDelay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self _endBackgroundTaskIfNeeded];
    });
}

- (void)_beginBackgroundTaskIfNeeded {
    dispatch_barrier_sync(MCSDownloadQueue(), ^{
        if ( _delegateDictionary.count != 0 && self->_backgroundTask == UIBackgroundTaskInvalid ) {
            self->_backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                [self _endBackgroundTaskIfNeeded];
            }];
        }
    });
}

- (void)_endBackgroundTaskIfNeeded {
    dispatch_barrier_sync(MCSDownloadQueue(), ^{
        if ( _delegateDictionary.count == 0 && self->_backgroundTask != UIBackgroundTaskInvalid ) {
            [UIApplication.sharedApplication endBackgroundTask:_backgroundTask];
            _backgroundTask = UIBackgroundTaskInvalid;
        }
    });
}

#pragma mark -

- (void)setTaskCount:(NSInteger)taskCount {
    if ( taskCount < 0 ) return;
    dispatch_barrier_sync(MCSDownloadQueue(), ^{
        _taskCount = taskCount;
    });
}

- (NSInteger)taskCount {
    __block NSInteger taskCount = 0;
    dispatch_sync(MCSDownloadQueue(), ^{
        taskCount = _taskCount;
    });
    return taskCount;
}

- (void)_setDelegate:(nullable id<MCSDownloadTaskDelegate>)delegate forTask:(NSURLSessionTask *)task {
    dispatch_barrier_sync(MCSDownloadQueue(), ^{
        self->_delegateDictionary[@(task.taskIdentifier)] = delegate;
        if ( delegate == nil && self->_delegateDictionary.count == 0 ) {
            [self _endBackgroundTaskDelay];
        }
    });
}
- (nullable id<MCSDownloadTaskDelegate>)_delegateForTask:(NSURLSessionTask *)task {
    __block id<MCSDownloadTaskDelegate> delegate = nil;
    dispatch_sync(MCSDownloadQueue(), ^{
        delegate = self->_delegateDictionary[@(task.taskIdentifier)];
    });
    return delegate;
}

- (void)_setError:(nullable NSError *)error forTask:(NSURLSessionTask *)task {
    dispatch_barrier_sync(MCSDownloadQueue(), ^{
        self->_errorDictionary[@(task.taskIdentifier)] = error;
    });
}

- (nullable NSError *)_errorForTask:(NSURLSessionTask *)task {
    __block NSError *error;
    dispatch_sync(MCSDownloadQueue(), ^{
        error = self->_errorDictionary[@(task.taskIdentifier)];
    });
    return error;
}

#ifdef DEBUG
- (void)_setStartTime:(uint64_t)time forTask:(NSURLSessionTask *)task {
    dispatch_barrier_sync(MCSDownloadQueue(), ^{
        self->_responseTimeDictionary[@(task.taskIdentifier)] = @(time);
    });
}

- (uint64_t)_startTimeForTask:(NSURLSessionTask *)task remove:(BOOL)remove {
    __block uint64_t time = 0;
    dispatch_sync(MCSDownloadQueue(), ^{
        time = [_responseTimeDictionary[@(task.taskIdentifier)] unsignedLongLongValue];
    });
    if ( remove ) {
        dispatch_barrier_sync(MCSDownloadQueue(), ^{
            self->_responseTimeDictionary[@(task.taskIdentifier)] = nil;
        });
    }
    return time;
}
#endif
@end
