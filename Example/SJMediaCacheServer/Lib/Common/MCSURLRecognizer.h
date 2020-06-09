//
//  MCSURLRecognizer.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSURLRecognizer : NSObject<MCSURLRecognizer>
+ (instancetype)shared;
- (nullable NSURL *)proxyURLWithURL:(NSURL *)URL localServerURL:(NSURL *)serverURL;
- (nullable NSURL *)URLWithProxyURL:(NSURL *)proxyURL;

- (nullable NSString *)resourceNameForURL:(NSURL *)URL;
- (MCSResourceType)resourceTypeForURL:(NSURL *)URL;
@end

NS_ASSUME_NONNULL_END
