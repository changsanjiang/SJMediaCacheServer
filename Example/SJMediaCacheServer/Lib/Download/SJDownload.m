//
//  SJDataDownload.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJDownload.h"
#import "SJError.h"
#import "SJUtils.h"

@interface SJDownload () <NSURLSessionDataDelegate, NSLocking>
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSOperationQueue *sessionDelegateQueue;
@property (nonatomic, strong) NSURLSessionConfiguration *sessionConfiguration;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSError *> *errorDictionary;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, id<SJDownloadTaskDelegate>> *delegateDictionary;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@end

@implementation SJDownload
+ (instancetype)shared {
    static SJDownload *obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[self alloc] init];
    });
    return obj;
}

- (instancetype)init {
    if (self = [super init]) {
        _semaphore = dispatch_semaphore_create(1);
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
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray<NSString *> *)availableHeaderKeys {
    static NSArray<NSString *> *obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = @[@"User-Agent",
                @"Connection",
                @"Accept",
                @"Accept-Encoding",
                @"Accept-Language",
                @"Range"];
    });
    return obj;
}
 
- (nullable NSURLSessionTask *)downloadWithRequest:(NSURLRequest *)requestParam delegate:(id<SJDownloadTaskDelegate>)delegate {
    [self lock];
    @try {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestParam.URL cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:_timeoutInterval];
        __auto_type availableHeaderKeys = self.availableHeaderKeys;
        [requestParam.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
            if ( [availableHeaderKeys containsObject:key] ) {
                [request setValue:obj forHTTPHeaderField:key];
            }
        }];
        
        if ( _requestHandler != nil )
            request = _requestHandler(request);
        
        if ( request == nil )
            return nil;
        
        NSURLSessionDataTask *task = [_session dataTaskWithRequest:request];
        _delegateDictionary[@(task.taskIdentifier)] = delegate;
        task.priority = 1.0;
        [task resume];
        return task;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    [self lock];
    completionHandler(request);
    [self unlock];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    [self lock];
    @try {
        NSError *error = nil;
        if ( response.statusCode > 400 ) {
            error = [SJError errorForResponseUnavailable:task.currentRequest.URL request:task.currentRequest response:task.response];
        }
        
        if ( error == nil ) {
            NSUInteger contentLength = SJGetResponseContentLength(response);
            if ( contentLength == 0 ) {
                error = [SJError errorForResponseUnavailable:task.currentRequest.URL request:task.currentRequest response:response];
            }
        }
        
        if ( error == nil ) {
            NSRange requestRange = SJGetRequestNSRange(SJGetRequestContentRange(task.currentRequest.allHTTPHeaderFields));
            NSRange responseRange = SJGetResponseNSRange(SJGetResponseContentRange(response));
            
            if ( !SJNSRangeIsUndefined(requestRange) ) {
                if ( SJNSRangeIsUndefined(responseRange) || !NSEqualRanges(requestRange, responseRange) ) {
                    error = [SJError errorForNonsupportContentType:task.currentRequest.URL request:task.currentRequest response:task.response];
                }
            }
        }
        
#warning next ... storage
        //    if (!error) {
        //        long long (^getDeletionLength)(long long) = ^(long long desireLength){
        //            return desireLength + [SJDataStorage storage].totalCacheLength - [SJDataStorage storage].maxCacheLength;
        //        };
        //        long long length = getDeletionLength(dataResponse.contentLength);
        //        if (length > 0) {
        //            [[SJDataUnitPool pool] deleteUnitsWithLength:length];
        //            length = getDeletionLength(dataResponse.contentLength);
        //            if (length > 0) {
        //                error = [SJError errorForNotEnoughDiskSpace:dataResponse.totalLength
        //                                                       request:dataResponse.contentLength
        //                                              totalCacheLength:[SJDataStorage storage].totalCacheLength
        //                                                maxCacheLength:[SJDataStorage storage].maxCacheLength];
        //            }
        //        }
        //    }
        
        NSNumber *key = @(task.taskIdentifier);
        if ( error == nil ) {
            id<SJDownloadTaskDelegate> delegate = _delegateDictionary[key];
            [delegate downloadTask:task didReceiveResponse:response];
            completionHandler(NSURLSessionResponseAllow);
        }
        else {
            _errorDictionary[key] = error;
            completionHandler(NSURLSessionResponseCancel);
        }
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self lock];
    @try {
        NSNumber *key = @(dataTask.taskIdentifier);
        __auto_type delegate = _delegateDictionary[key];
        [delegate downloadTask:dataTask didReceiveData:data];
    } @catch (__unused NSException *exception) {
            
    } @finally {
        [self unlock];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [self lock];
    @try {
        NSNumber *key = @(task.taskIdentifier);
        if ( _errorDictionary[key] != nil )
            error = _errorDictionary[key];
        
        __auto_type delegate = _delegateDictionary[key];
        [delegate downloadTask:task didCompleteWithError:error];
        
        _delegateDictionary[key] = nil;
        _errorDictionary[key] = nil;
        
        if ( _delegateDictionary.count == 0 )
            [self endBackgroundTaskDelay];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

#pragma mark -

- (void)lock {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
}

- (void)unlock {
    dispatch_semaphore_signal(_semaphore);
}

#pragma mark - Background Task

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    [self lock];
    @try {
        if ( _delegateDictionary.count > 0 )
            [self beginBackgroundTask];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    [self endBackgroundTask];
}

- (void)endBackgroundTaskDelay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self lock];
        @try {
            if ( _delegateDictionary.count == 0 )
                [self endBackgroundTask];
        } @catch (__unused NSException *exception) {
            
        } @finally {
            [self unlock];
        }
    });
}

- (void)beginBackgroundTask {
    _backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self endBackgroundTask];
    }];
}

- (void)endBackgroundTask {
    if ( _backgroundTask != UIBackgroundTaskInvalid ) {
        [UIApplication.sharedApplication endBackgroundTask:_backgroundTask];
        _backgroundTask = UIBackgroundTaskInvalid;
    }
}

@end
