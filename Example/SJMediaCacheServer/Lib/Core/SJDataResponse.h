//
//  SJDataResponse.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJMediaCacheServerDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SJDataResponse : NSObject<SJDataResponse>
- (instancetype)initWithRequest:(SJDataRequest *)request delegate:(id<SJDataResponseDelegate>)delegate;

- (void)prepare;
@property (nonatomic, readonly) UInt64 contentLength;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
@property (nonatomic, readonly) UInt64 offset;
@property (nonatomic, readonly) BOOL isDone;
- (void)close;

@end

NS_ASSUME_NONNULL_END
