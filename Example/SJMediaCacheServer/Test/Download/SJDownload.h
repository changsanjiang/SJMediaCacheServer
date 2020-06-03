//
//  SJDataDownload.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol SJDownloadTaskDelegate;
NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString * const SJContentTypeVideo;
FOUNDATION_EXPORT NSString * const SJContentTypeAudio;
FOUNDATION_EXPORT NSString * const SJContentTypeApplicationMPEG4;
FOUNDATION_EXPORT NSString * const SJContentTypeApplicationOctetStream;
FOUNDATION_EXPORT NSString * const SJContentTypeBinaryOctetStream;

@interface SJDownload : NSObject
+ (instancetype)shared;

@property (nonatomic) NSTimeInterval timeoutInterval;

/**
 *  Header Fields
 */
@property (nonatomic, copy) NSArray<NSString *> *whitelistHeaderKeys;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *additionalHeaders;

/**
 *  Content-Type
 */
@property (nonatomic, copy) NSArray<NSString *> *acceptableContentTypes;
@property (nonatomic, copy) BOOL(^unacceptableContentTypeDisposer)(NSURL *URL, NSString *contentType);

- (NSURLSessionTask *)downloadWithRequest:(NSURLRequest *)request delegate:(id<SJDownloadTaskDelegate>)delegate;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

@protocol SJDownloadTaskDelegate <NSObject>
- (void)downloadTask:(NSURLSessionTask *)task didReceiveResponse:(NSURLResponse *)response;
- (void)downloadTask:(NSURLSessionTask *)task didReceiveData:(NSData *)data;
- (void)downloadTask:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error;
@end
NS_ASSUME_NONNULL_END
