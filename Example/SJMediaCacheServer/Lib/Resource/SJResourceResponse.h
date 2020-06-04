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
- (instancetype)initWithRange:(NSRange)range allHeaderFields:(NSDictionary *)allHeaderFields;
@property (nonatomic, copy, readonly, nullable) NSDictionary *responseHeaders;
@property (nonatomic, readonly) NSUInteger contentLength;
@property (nonatomic, readonly) NSRange contentRange;
@end

NS_ASSUME_NONNULL_END
