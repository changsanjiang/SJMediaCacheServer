//
//  SJURLConvertor.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJMediaCacheServerDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SJURLConvertor : NSObject<SJURLConvertor>
+ (instancetype)shared;
- (nullable NSURL *)proxyURLWithURL:(NSURL *)URL;
- (nullable NSURL *)URLWithProxyURL:(NSURL *)proxyURL;
- (nullable NSString *)URLKeyWithURL:(NSURL *)URL;
@end

NS_ASSUME_NONNULL_END
