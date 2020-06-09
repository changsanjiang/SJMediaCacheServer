//
//  MCSDefines.h
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#ifndef MCSDefines_h
#define MCSDefines_h
#import <Foundation/Foundation.h>
#import "NSURLRequest+MCS.h"
@protocol MCSDataResponseDelegate, MCSResourcePrefetcherDelegate, MCSResourceReaderDelegate;
@protocol MCSResource, MCSResourceResponse, MCSResourceReader, MCSResourcePrefetcher;


NS_ASSUME_NONNULL_BEGIN
@protocol MCSURLConvertor <NSObject>
- (nullable NSURL *)proxyURLWithURL:(NSURL *)URL localServerURL:(NSURL *)serverURL;
- (nullable NSURL *)URLWithProxyURL:(NSURL *)proxyURL;
- (nullable NSString *)resourceNameWithURL:(NSURL *)URL;
@end

@protocol MCSDataResponse <NSObject>
- (instancetype)initWithRequest:(NSURLRequest *)request delegate:(id<MCSDataResponseDelegate>)delegate;

- (void)prepare;
@property (nonatomic, copy, readonly, nullable) NSDictionary *responseHeaders;
@property (nonatomic, readonly) NSUInteger contentLength;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
@property (nonatomic, readonly) NSUInteger offset;
@property (nonatomic, readonly) BOOL isPrepared;
@property (nonatomic, readonly) BOOL isDone;
- (void)close;
@end

@protocol MCSDataResponseDelegate <NSObject>
- (void)responsePrepareDidFinish:(id<MCSDataResponse>)response;
- (void)responseHasAvailableData:(id<MCSDataResponse>)response;
- (void)response:(id<MCSDataResponse>)response anErrorOccurred:(NSError *)error;
@end
 
#pragma mark -

@protocol MCSResource <NSObject>
+ (instancetype)resourceWithURL:(NSURL *)URL;
 
- (id<MCSResourceReader>)readerWithRequest:(NSURLRequest *)request;
- (id<MCSResourcePrefetcher>)prefetcherWithRequest:(NSURLRequest *)request;
@end

#pragma mark -

@protocol MCSResourceResponse <NSObject>
@property (nonatomic, copy, readonly, nullable) NSDictionary *responseHeaders;
- (nullable NSString *)contentType;
- (nullable NSString *)server;
- (NSUInteger)totalLength;
- (NSRange)contentRange;
@end

#pragma mark -

@protocol MCSResourceReader <NSObject>
@property (nonatomic, weak, nullable) id<MCSResourceReaderDelegate> delegate;

- (void)prepare;
@property (nonatomic, strong, readonly, nullable) id<MCSResourceResponse> response;
@property (nonatomic, readonly) NSUInteger offset;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
@property (nonatomic, readonly) BOOL isPrepared;
@property (nonatomic, readonly) BOOL isReadingEndOfData;
@property (nonatomic, readonly) BOOL isClosed;
- (void)close;
@end

@protocol MCSResourceReaderDelegate <NSObject>
- (void)readerPrepareDidFinish:(id<MCSResourceReader>)reader;
- (void)readerHasAvailableData:(id<MCSResourceReader>)reader;
- (void)reader:(id<MCSResourceReader>)reader anErrorOccurred:(NSError *)error;
@end

#pragma mark -

@protocol MCSResourcePrefetcher <NSObject>
@property (nonatomic, weak, nullable) id<MCSResourcePrefetcherDelegate> delegate;
@property (nonatomic, readonly) BOOL isPrepared;
@property (nonatomic, readonly) BOOL isFinished;
@property (nonatomic, readonly) BOOL isClosed;
- (void)prepare;
- (void)close;
@end


@protocol MCSResourcePrefetcherDelegate <NSObject>
- (void)prefetcherPrepareDidFinish:(id<MCSResourcePrefetcher>)prefetcher;
- (void)prefetcherPrefetchDidFinish:(id<MCSResourcePrefetcher>)prefetcher;
- (void)prefetcher:(id<MCSResourcePrefetcher>)prefetcher anErrorOccurred:(NSError *)error;
@end
NS_ASSUME_NONNULL_END

#endif /* MCSDefines_h */
