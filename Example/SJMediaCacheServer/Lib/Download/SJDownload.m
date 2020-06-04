//
//  SJDataDownload.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJDownload.h"
#import "SJError.h"

NSString * const SJContentTypeVideo                  = @"video/";
NSString * const SJContentTypeAudio                  = @"audio/";
NSString * const SJContentTypeApplicationMPEG4       = @"application/mp4";
NSString * const SJContentTypeApplicationOctetStream = @"application/octet-stream";
NSString * const SJContentTypeBinaryOctetStream      = @"binary/octet-stream";

@interface SJDownload () <NSURLSessionDataDelegate, NSLocking>
@property (nonatomic, strong) NSLock *coreLock;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSOperationQueue *sessionDelegateQueue;
@property (nonatomic, strong) NSURLSessionConfiguration *sessionConfiguration;
@property (nonatomic, strong) NSMutableDictionary<NSURLSessionTask *, NSError *> *errorDictionary;
@property (nonatomic, strong) NSMutableDictionary<NSURLSessionTask *, NSURLRequest *> *requestDictionary;
@property (nonatomic, strong) NSMutableDictionary<NSURLSessionTask *, id<SJDownloadTaskDelegate>> *delegateDictionary;
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
        self.timeoutInterval = 30.0f;
        self.backgroundTask = UIBackgroundTaskInvalid;
        self.errorDictionary = [NSMutableDictionary dictionary];
        self.requestDictionary = [NSMutableDictionary dictionary];
        self.delegateDictionary = [NSMutableDictionary dictionary];
        self.sessionDelegateQueue = [[NSOperationQueue alloc] init];
        self.sessionDelegateQueue.qualityOfService = NSQualityOfServiceUserInteractive;
        self.sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.sessionConfiguration.timeoutIntervalForRequest = self.timeoutInterval;
        self.sessionConfiguration.requestCachePolicy = NSURLRequestReloadIgnoringCacheData;
        self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration
                                                     delegate:self
                                                delegateQueue:self.sessionDelegateQueue];
        self.acceptableContentTypes = @[SJContentTypeVideo,
                                        SJContentTypeAudio,
                                        SJContentTypeApplicationMPEG4,
                                        SJContentTypeApplicationOctetStream,
                                        SJContentTypeBinaryOctetStream];
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

- (NSURLSessionTask *)downloadWithRequest:(NSURLRequest *)request delegate:(id<SJDownloadTaskDelegate>)delegate {
    [self lock];
    NSMutableURLRequest *mRequest = [NSMutableURLRequest requestWithURL:request.URL];
    mRequest.timeoutInterval = self.timeoutInterval;
    mRequest.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    [request.allHTTPHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        if ([self.availableHeaderKeys containsObject:key] ||
            [self.whitelistHeaderKeys containsObject:key]) {
            [mRequest setValue:obj forHTTPHeaderField:key];
        }
    }];
    [self.additionalHeaders enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        [mRequest setValue:obj forHTTPHeaderField:key];
    }];
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:mRequest];
    [self.requestDictionary setObject:request forKey:task];
    [self.delegateDictionary setObject:delegate forKey:task];
    task.priority = 1.0;
    [task resume];
    [self unlock];
    return task;
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [self lock];
    if ([self.errorDictionary objectForKey:task]) {
        error = [self.errorDictionary objectForKey:task];
    }
    id<SJDownloadTaskDelegate> delegate = [self.delegateDictionary objectForKey:task];
    [delegate downloadTask:task didCompleteWithError:error];
    [self.delegateDictionary removeObjectForKey:task];
    [self.requestDictionary removeObjectForKey:task];
    [self.errorDictionary removeObjectForKey:task];
    if (self.delegateDictionary.count <= 0) {
        [self endBackgroundTaskDelay];
    }
    [self unlock];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSHTTPURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    [self lock];
    
    NSLog(@"%@", response);
    
//    SJDataRequest *dataRequest = [self.requestDictionary objectForKey:task];
//    SJDataResponse *dataResponse = [[SJDataResponse alloc] initWithURL:dataRequest.URL headers:response.allHeaderFields];
    NSError *error = nil;
    if (!error) {
        if (response.statusCode > 400) {
            error = [SJError errorForResponseUnavailable:task.currentRequest.URL request:task.currentRequest response:task.response];
        }
    }
//    if (!error) {
//        BOOL vaild = NO;
//        if (dataResponse.contentType.length > 0) {
//            for (NSString *obj in self.acceptableContentTypes) {
//                if ([[dataResponse.contentType lowercaseString] containsString:[obj lowercaseString]]) {
//                    vaild = YES;
//                }
//            }
//            if (!vaild && self.unacceptableContentTypeDisposer) {
//                vaild = self.unacceptableContentTypeDisposer(dataRequest.URL, dataResponse.contentType);
//            }
//        }
//        if (!vaild) {
//            error = [SJError errorForUnsupportContentType:task.currentRequest.URL
//                                                     request:task.currentRequest
//                                                    response:task.response];
//        }
//    }
//    if (!error) {
//        if (dataResponse.contentLength <= 0 ||
//            (!SJRangeIsFull(dataRequest.range) &&
//             (dataResponse.contentLength != SJRangeGetLength(dataRequest.range)))) {
//                error = [SJError errorForUnsupportContentType:task.currentRequest.URL
//                                                         request:task.currentRequest
//                                                        response:task.response];
//            }
//    }
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
    if ( error ) {
        [self.errorDictionary setObject:error forKey:task];
        completionHandler(NSURLSessionResponseCancel);
    } else {
        id<SJDownloadTaskDelegate> delegate = [self.delegateDictionary objectForKey:task];
        [delegate downloadTask:task didReceiveResponse:response];
        completionHandler(NSURLSessionResponseAllow);
    }
    [self unlock];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    [self lock];
    completionHandler(request);
    [self unlock];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self lock];
    id<SJDownloadTaskDelegate> delegate = [self.delegateDictionary objectForKey:dataTask];
    [delegate downloadTask:dataTask didReceiveData:data];
    [self unlock];
}

- (void)lock {
    if (!self.coreLock) {
        self.coreLock = [[NSLock alloc] init];
    }
    [self.coreLock lock];
}

- (void)unlock {
    [self.coreLock unlock];
}

#pragma mark - Background Task

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    [self lock];
    if (self.delegateDictionary.count > 0) {
        [self beginBackgroundTask];
    }
    [self unlock];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    [self endBackgroundTask];
}

- (void)beginBackgroundTask {
    self.backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self endBackgroundTask];
    }];
}

- (void)endBackgroundTask {
    if (self.backgroundTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }
}

- (void)endBackgroundTaskDelay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self lock];
        if (self.delegateDictionary.count <= 0) {
            [self endBackgroundTask];
        }
        [self unlock];
    });
}
@end
