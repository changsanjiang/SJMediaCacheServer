//
//  SJDownloadDataTask.m
//  SJDownloadDataTask
//
//  Created by 畅三江 on 2018/5/26.
//  Copyright © 2018年 畅三江. All rights reserved.
//

#import "SJDownloadDataTask.h"
#import <SJUIKit/NSObject+SJObserverHelper.h>
#import "NSTimer+SJDownloadDataTaskAdd.h"
#import "SJURLSessionDataTaskServer.h"
#import "SJOutPutStream.h"

NS_ASSUME_NONNULL_BEGIN
@interface SJDownloadDataTask ()<NSURLSessionDelegate>
@property (weak, nullable) NSURLSessionDataTask *dataTask;
@property (nonatomic, strong, nullable) NSProgress *downloadProgress;
@property (nonatomic, strong, nullable) SJOutPutStream *outPutStream;
@end

@implementation SJDownloadDataTask {
    SJDownloadDataTaskIdentitifer _identifier;
    NSString *_URLStr;
    NSURL *_fileURL;
    
    /// Blocks
    BOOL(^_Nullable _responseBlock)(SJDownloadDataTask *dataTask, NSURLResponse *response);
    void(^_Nullable _progressBlock)(SJDownloadDataTask *dataTask, float progress);
    void(^_Nullable _successBlock)(SJDownloadDataTask *dataTask);
    void(^_Nullable _failureBlock)(SJDownloadDataTask *dataTask);
}

#ifdef DEBUG
- (void)dealloc {
    NSLog(@"%d - %s", (int)__LINE__, __func__);
}
#endif

+ (SJDownloadDataTask *)downloadWithURLStr:(NSString *)URLStr
                                    toPath:(NSURL *)fileURL
                                  progress:(nullable void (^)(SJDownloadDataTask * _Nonnull, float))progressBlock
                                   success:(nullable void (^)(SJDownloadDataTask * _Nonnull))successBlock
                                   failure:(nullable void (^)(SJDownloadDataTask * _Nonnull))failureBlock {
    return [self downloadWithURLStr:URLStr
                             toPath:fileURL
                             append:NO
                           progress:progressBlock
                            success:successBlock
                            failure:failureBlock];
}

+ (SJDownloadDataTask *)downloadWithURLStr:(NSString *)URLStr
                                    toPath:(NSURL *)fileURL
                                    append:(BOOL)shouldAppend // YES if newly written data should be appended to any existing file contents, otherwise NO.
                                  progress:(nullable void(^)(SJDownloadDataTask *dataTask, float progress))progressBlock
                                   success:(nullable void(^)(SJDownloadDataTask *dataTask))successBlock
                                   failure:(nullable void(^)(SJDownloadDataTask *dataTask))failureBlock {
    return [self downloadWithURLStr:URLStr
                             toPath:fileURL
                             append:shouldAppend
                           response:nil
                           progress:progressBlock
                            success:successBlock
                            failure:failureBlock];
}

+ (SJDownloadDataTask *)downloadWithURLStr:(NSString *)URLStr
                                    toPath:(NSURL *)fileURL
                                    append:(BOOL)shouldAppend // YES if newly written data should be appended to any existing file contents, otherwise NO.
                                  response:(nullable BOOL(^)(SJDownloadDataTask *dataTask, NSURLResponse *response))responseBlock
                                  progress:(nullable void(^)(SJDownloadDataTask *dataTask, float progress))progressBlock
                                   success:(nullable void(^)(SJDownloadDataTask *dataTask))successBlock
                                   failure:(nullable void(^)(SJDownloadDataTask *dataTask))failureBlock {
    SJDownloadDataTask *task = [[SJDownloadDataTask alloc] initWithPath:fileURL append:shouldAppend];
    task->_URLStr = URLStr;
    task->_responseBlock = responseBlock;
    task->_progressBlock = progressBlock;
    task->_successBlock = successBlock;
    task->_failureBlock = failureBlock;
    [task restart];
    return task;
}

- (instancetype)initWithPath:(NSURL *)fileURL append:(BOOL)shouldAppend {
    self = [super init];
    if ( self ) {
        _identifier = [self hash];
        _shouldAppend = shouldAppend;
        _fileURL = fileURL;
        _outPutStream = [[SJOutPutStream alloc] initWithPath:fileURL append:shouldAppend];
        
        long long wroteSize = 0;
        if ( shouldAppend == YES ) {
            wroteSize = [[[[NSFileManager defaultManager] attributesOfItemAtPath:fileURL.path error:nil] valueForKey:NSFileSize] longLongValue];
        }
        
        _downloadProgress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
        _downloadProgress.totalUnitCount = NSURLResponseUnknownLength;
        _downloadProgress.completedUnitCount = wroteSize;
        [_downloadProgress sj_addObserver:self
                               forKeyPath:@"completedUnitCount"
                                  options:NSKeyValueObservingOptionNew
                                  context:NULL];
    }
    return self;
}

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey,id> *)change context:(nullable void *)context {
    if ( _progressBlock )
        _progressBlock(self, self.progress);
}

- (void)restart {
    @synchronized (self) {
        if ( _dataTask != nil && _dataTask.state == NSURLSessionTaskStateRunning ) {
            return;
        }
        
        NSURL *URL = [NSURL URLWithString:_URLStr];
        _dataTask = [self _createDataTaskWithURL:URL wroteSize:_downloadProgress.completedUnitCount];
        [_dataTask resume];
        [_outPutStream open];
        
#ifdef SJ_MAC
        if ( _shouldAppend == YES ) {
            printf("\nSJDownloadDataTask: 此次下载为追加模式, 将会向文件中追加剩余数据. 当前文件大小为: %lld\n",
                   _downloadProgress.completedUnitCount);
        } else {
            printf("\nSJDownloadDataTask: 此次下载将覆盖原始文件数据(如果此路径存在文件:[%s])\n",
                   _fileURL.absoluteString.UTF8String);
        }
#endif
    }
}

- (void)cancel {
    @synchronized (self) {
        [_dataTask cancel];
        [_outPutStream close];
    }
}

#pragma mark -

- (NSURLSessionDataTask *)_createDataTaskWithURL:(NSURL *)URL wroteSize:(long long)wroteSize {
    return [SJURLSessionDataTaskServer.shared dataTaskWithURL:URL wroteSize:wroteSize response:^BOOL(NSURLSessionDataTask * _Nonnull dataTask) {
        return [self _didReceiveResponse:dataTask];
    } receivedData:^(NSURLSessionDataTask * _Nonnull dataTask, NSData * _Nonnull data) {
        [self _didReceiveData:data];
    } completion:^(NSURLSessionDataTask * _Nonnull dataTask) {
        [self _didComplete:dataTask];
    } cancelled:^(NSURLSessionDataTask * _Nonnull dataTask) {
        [self _didCancel:dataTask];
    }];
}

- (BOOL)_didReceiveResponse:(NSURLSessionDataTask *)dataTask {
#ifdef SJ_MAC
    long long exp = dataTask.response.expectedContentLength;
    if ( dataTask.response.expectedContentLength == 0 ) {
        printf("\nSJDownloadDataTask: 接收到服务器响应, 但返回响应的文件大小为 0, 该文件可能已下载完毕. 我将取消本次请求, 并回调`successBlock`\n");
    }
    else {
        printf("\nSJDownloadDataTask: 接收到服务器响应, 文件总大小: %lld, 下载标识:%ld \n",
               exp + _downloadProgress.completedUnitCount,
               (unsigned long)dataTask.taskIdentifier);
    }
#endif
    
    long long expectedContentLength = dataTask.response.expectedContentLength;
    if ( expectedContentLength != 0 ) {
        _downloadProgress.totalUnitCount = expectedContentLength + _downloadProgress.completedUnitCount;
        if ( _responseBlock )
            return _responseBlock(self, dataTask.response);
        return YES;
    }
    else {
        self->_successBlock(self);
        return NO;
    }
}

- (void)_didReceiveData:(NSData *)data {
    [_outPutStream write:data];
    _downloadProgress.completedUnitCount += data.length;
}

- (void)_didComplete:(NSURLSessionDataTask *)dataTask {

    [_outPutStream close];
    if ( dataTask.error != nil ) {
        if ( _failureBlock != nil ) {
            _failureBlock(self);
        }
    }
    else if ( _successBlock != nil ) {
        _successBlock(self);
    }

#ifdef SJ_MAC
    if ( dataTask.error != nil ) {
        printf("\nSJDownloadDataTask: 下载错误, error: %s, 下载标识:%ld \n",
               [dataTask.error.description UTF8String],
               (unsigned long)dataTask.taskIdentifier);
    }
    else {
        printf("\nSJDownloadDataTask: 文件下载完成, 下载标识: %ld, 保存路径:%s \n",
               (unsigned long)dataTask.taskIdentifier,
               [_fileURL.description UTF8String]);
    }
#endif
}

- (void)_didCancel:(NSURLSessionDataTask *)dataTask {
    [_outPutStream close];
    
#ifdef SJ_MAC
    printf("\nSJDownloadDataTask: 下载被取消, 下载标识:%ld \n", (unsigned long)dataTask.taskIdentifier);
#endif
}

- (int64_t)wroteSize {
    if ( _downloadProgress.totalUnitCount == NSURLResponseUnknownLength ) {
        return 0;
    }
    return _downloadProgress.completedUnitCount;
}

- (int64_t)totalSize {
    if ( _downloadProgress.totalUnitCount == NSURLResponseUnknownLength ) {
        return 0;
    }
    return _downloadProgress.totalUnitCount;
}

- (float)progress {
    if ( _downloadProgress.totalUnitCount == NSURLResponseUnknownLength ) {
        return 0;
    }
    
    if ( _downloadProgress.totalUnitCount != 0 )
        return _downloadProgress.completedUnitCount * 1.0 / _downloadProgress.totalUnitCount;
    return 0;
}

- (nullable NSError *)error {
    @synchronized (self) {
        if ( _dataTask.error.code != NSURLErrorCancelled )
            return _dataTask.error;
        return nil;
    }
}
@end
NS_ASSUME_NONNULL_END
