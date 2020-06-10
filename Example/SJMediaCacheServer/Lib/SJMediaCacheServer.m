//
//  SJMediaCacheServer.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJMediaCacheServer.h"
#import "MCSProxyServer.h"
#import "MCSResourceManager.h"

@interface SJMediaCacheServer ()
@property (nonatomic, strong, readonly) MCSProxyServer *server;
@end

@implementation SJMediaCacheServer
+ (instancetype)shared {
    static id obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[self alloc] init];
    });
    return obj;
}

- (instancetype)init {
    self = [super init];
    if ( self ) {
        _server = [MCSProxyServer.alloc initWithPort:2000];
        [_server start];
    }
    return self;
}

- (NSURL *)playbackURLWithURL:(NSURL *)URL {
    if ( URL.isFileURL )
        return URL;
    MCSResource *resource = [MCSResourceManager.shared resourceWithURL:URL];
    
    return URL;
}
@end
