//
//  SJURLSessionDataTaskServer.h
//  SJDownloadDataTask
//
//  Created by BlueDancer on 2019/5/13.
//  Copyright © 2019 畅三江. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef BOOL(^SJURLSessionDataTaskResponseHandler)(NSURLSessionDataTask *dataTask);
typedef void(^SJURLSessionDataTaskReceivedDataHandler)(NSURLSessionDataTask *dataTask, NSData *data);
typedef void(^SJURLSessionDataTaskCompletionHandler)(NSURLSessionDataTask *dataTask);
typedef void(^SJURLSessionDataTaskCancelledHandler)(NSURLSessionDataTask *dataTask);

@interface SJURLSessionDataTaskServer : NSObject
+ (instancetype)shared;

- (nullable NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)URL
                                         wroteSize:(long long)wroteSize
                                          response:(nullable SJURLSessionDataTaskResponseHandler)responseHandler
                                      receivedData:(nullable SJURLSessionDataTaskReceivedDataHandler)receivedDataHandler
                                        completion:(nullable SJURLSessionDataTaskCompletionHandler)completionHandler
                                         cancelled:(nullable SJURLSessionDataTaskCancelledHandler)cancelledHandler;
@end
NS_ASSUME_NONNULL_END
