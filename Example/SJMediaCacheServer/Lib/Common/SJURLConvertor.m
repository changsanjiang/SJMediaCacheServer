//
//  SJURLConvertor.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJURLConvertor.h"

@implementation SJURLConvertor
+ (instancetype)shared {
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (nullable NSURL *)proxyURLWithURL:(NSURL *)URL {
    return nil;
}

- (nullable NSURL *)URLWithProxyURL:(NSURL *)proxyURL {
    return nil;
}

- (nullable NSString *)URLKeyWithURL:(NSURL *)URL {
    return nil;
}
@end
