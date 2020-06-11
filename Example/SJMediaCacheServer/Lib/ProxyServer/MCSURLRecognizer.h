//
//  MCSURLRecognizer.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDefines.h"
#import "MCSProxyServer.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSURLRecognizer : NSObject
+ (instancetype)shared;

@property (nonatomic, weak, nullable) MCSProxyServer *server;

- (NSURL *)proxyURLWithURL:(NSURL *)URL localServerURL:(NSURL *)serverURL;
- (NSURL *)URLWithProxyURL:(NSURL *)proxyURL;

- (NSString *)resourceNameForURL:(NSURL *)URL;
- (MCSResourceType)resourceTypeForURL:(NSURL *)URL;
@end

NS_ASSUME_NONNULL_END
