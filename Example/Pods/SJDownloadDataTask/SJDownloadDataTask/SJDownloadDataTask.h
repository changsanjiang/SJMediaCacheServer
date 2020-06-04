//
//  SJDownloadDataTask.h
//  SJDownloadDataTask
//
//  Created by 畅三江 on 2018/5/26.
//  Copyright © 2018年 畅三江. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NSUInteger SJDownloadDataTaskIdentitifer;

@interface SJDownloadDataTask : NSObject

+ (SJDownloadDataTask *)downloadWithURLStr:(NSString *)URLStr
                                    toPath:(NSURL *)fileURL
                                  progress:(nullable void(^)(SJDownloadDataTask *dataTask, float progress))progressBlock
                                   success:(nullable void(^)(SJDownloadDataTask *dataTask))successBlock
                                   failure:(nullable void(^)(SJDownloadDataTask *dataTask))failureBlock;

+ (SJDownloadDataTask *)downloadWithURLStr:(NSString *)URLStr
                                    toPath:(NSURL *)fileURL
                                    append:(BOOL)shouldAppend // YES if newly written data should be appended to any existing file contents, otherwise NO.
                                  progress:(nullable void(^)(SJDownloadDataTask *dataTask, float progress))progressBlock
                                   success:(nullable void(^)(SJDownloadDataTask *dataTask))successBlock
                                   failure:(nullable void(^)(SJDownloadDataTask *dataTask))failureBlock;

+ (SJDownloadDataTask *)downloadWithURLStr:(NSString *)URLStr
                                    toPath:(NSURL *)fileURL
                                    append:(BOOL)shouldAppend // YES if newly written data should be appended to any existing file contents, otherwise NO.
                                  response:(nullable BOOL(^)(SJDownloadDataTask *dataTask, NSURLResponse *response))responseBlock
                                  progress:(nullable void(^)(SJDownloadDataTask *dataTask, float progress))progressBlock
                                   success:(nullable void(^)(SJDownloadDataTask *dataTask))successBlock
                                   failure:(nullable void(^)(SJDownloadDataTask *dataTask))failureBlock;

- (void)restart; // 重启下载
- (void)cancel;  // 取消下载
@property (nonatomic) BOOL shouldAppend;

@property (nonatomic, readonly) SJDownloadDataTaskIdentitifer identifier;
@property (nonatomic, strong, readonly) NSString *URLStr;
@property (nonatomic, strong, readonly) NSURL *fileURL;

@property (nonatomic, strong, readonly, nullable) NSError *error;
@property (nonatomic, readonly) float progress;
@property (nonatomic, readonly) int64_t totalSize; // 总size, 单位: byte
@property (nonatomic, readonly) int64_t wroteSize; // 已写入的size, 单位: byte
@end
NS_ASSUME_NONNULL_END
