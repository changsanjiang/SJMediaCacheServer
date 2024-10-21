//
//  SJDataDownload.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSInterfaces.h"
#import "MCSResponse.h"

NS_ASSUME_NONNULL_BEGIN
@interface MCSDownload : NSObject<MCSDownloader>
+ (instancetype)shared;

@property (nonatomic, strong, nullable) NSURLSessionConfiguration *initialSessionConfiguration;
@property (nonatomic, copy, nullable) void (^requestHandler)(NSMutableURLRequest *request);
@property (nonatomic, copy, null_resettable) id<MCSDownloadResponse> _Nullable(^responseHandler)(NSURLSessionTask *task, NSURLResponse *res);
@property (nonatomic, copy, nullable) NSData *(^receivedDataEncryptor)(NSURLRequest *request, NSUInteger offset, NSData *data);
@property (nonatomic, copy, nullable) void (^metricsHandler)(NSURLSession *session, NSURLSessionTask *task, NSURLSessionTaskMetrics *metrics);
@property (nonatomic) NSTimeInterval timeoutInterval; // default value is 30s;

- (nullable id<MCSDownloadTask>)downloadWithRequest:(NSURLRequest *)request priority:(float)priority delegate:(id<MCSDownloadTaskDelegate>)delegate;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end


@interface MCSDownloadResponse : MCSResponse<MCSDownloadResponse>
- (instancetype)initWithOriginalRequest:(NSURLRequest *)originalRequest
                         currentRequest:(NSURLRequest *)currentRequest
                             statusCode:(NSInteger)statusCode
                          pathExtension:(NSString *_Nullable)pathExtension
                            totalLength:(NSUInteger)totalLength
                                  range:(NSRange)range
                            contentType:(NSString *_Nullable)contentType;
@property (nonatomic, copy, readonly) NSURLRequest  *originalRequest;  /* NSURLSessionTask; may be nil if this is a stream task */
@property (nonatomic, copy, readonly) NSURLRequest  *currentRequest;   /* NSURLSessionTask; may differ from originalRequest due to http server redirection */

@property (nonatomic, readonly) NSInteger statusCode;
@property (nonatomic, copy, readonly) NSString *pathExtension;

- (instancetype)initWithTotalLength:(NSUInteger)totalLength NS_UNAVAILABLE;
- (instancetype)initWithTotalLength:(NSUInteger)totalLength contentType:(nullable NSString *)contentType  NS_UNAVAILABLE;
- (instancetype)initWithTotalLength:(NSUInteger)totalLength range:(NSRange)range NS_UNAVAILABLE;
- (instancetype)initWithTotalLength:(NSUInteger)totalLength range:(NSRange)range contentType:(nullable NSString *)contentType NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
