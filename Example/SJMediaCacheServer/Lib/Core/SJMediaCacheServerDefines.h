//
//  SJMediaCacheServerDefines.h
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#ifndef SJMediaCacheServerDefines_h
#define SJMediaCacheServerDefines_h
@protocol SJDataResponseDelegate;

NS_ASSUME_NONNULL_BEGIN
@protocol SJDataRequest <NSObject>
@property (nonatomic, copy, readonly, nullable) NSURL *URL;
@property (nonatomic, copy, readonly, nullable) NSDictionary *headers;
@property (nonatomic, readonly) NSRange range;
@end

@protocol SJDataResponse <NSObject>
- (instancetype)initWithRequest:(id<SJDataRequest>)request delegate:(id<SJDataResponseDelegate>)delegate;

- (void)prepare;
@property (nonatomic, readonly) UInt64 contentLength;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
@property (nonatomic, readonly) UInt64 offset;
@property (nonatomic, readonly) BOOL isDone;
- (void)close;
@end

@protocol SJDataResponseDelegate <NSObject>
- (void)responsePrepareDidFinish:(id<SJDataResponse>)response;
- (void)responseHasAvailableData:(id<SJDataResponse>)response;
- (void)response:(id<SJDataResponse>)response anErrorOccurred:(NSError *)error;
@end
NS_ASSUME_NONNULL_END

#endif /* SJMediaCacheServerDefines_h */
