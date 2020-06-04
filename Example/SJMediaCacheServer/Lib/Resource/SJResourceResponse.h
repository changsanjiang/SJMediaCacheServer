//
//  SJResourceResponse.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/4.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJMediaCacheServerDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SJResourceResponse : NSObject<SJResourceResponse>
- (instancetype)initWithResponse:(NSHTTPURLResponse *)response;
- (instancetype)initWithServer:(NSString *)server contentType:(NSString *)contentType totalLength:(NSUInteger)totalLength contentRange:(NSRange)contentRange;

@property (nonatomic, copy, readonly, nullable) NSDictionary *responseHeaders;
@property (nonatomic, copy, readonly, nullable) NSString *contentType;
@property (nonatomic, copy, readonly, nullable) NSString *server;
@property (nonatomic, readonly) NSUInteger totalLength;
@property (nonatomic, readonly) NSRange contentRange;
@end

NS_ASSUME_NONNULL_END
