//
//  MCSDataResponse.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSDataResponse : NSObject<MCSDataResponse>
- (instancetype)initWithRequest:(MCSDataRequest *)request delegate:(id<MCSDataResponseDelegate>)delegate;

- (void)prepare;
@property (nonatomic, copy, readonly, nullable) NSDictionary *responseHeaders;
@property (nonatomic, readonly) NSUInteger contentLength;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
@property (nonatomic, readonly) NSUInteger offset;
@property (nonatomic, readonly) BOOL isDone;
- (void)close;

@end

NS_ASSUME_NONNULL_END
