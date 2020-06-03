//
//  SJViewController.m
//  SJMediaCacheServer
//
//  Created by changsanjiang@gmail.com on 05/30/2020.
//  Copyright (c) 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJViewController.h"
#import "SJMediaCacheServerDefines.h"
#import "SJLocalProxyServer.h"
#import <SJVideoPlayer/SJVideoPlayer.h>
#import <Masonry/Masonry.h>

#import "SJDataResponse.h"
#import "SJURLConvertor.h"

@interface SJViewController ()<SJLocalProxyServerDelegate>
@property (nonatomic, strong, nullable) SJLocalProxyServer *server;
@property (nonatomic, strong, nullable) SJVideoPlayer *player;
@end

@implementation SJViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self _setupViews];
    [self _startLocalProxyServer];

    // 播放
    
    NSURL *proxyURL = [SJURLConvertor.shared proxyURLWithURL:[NSURL URLWithString:@"https://dh2.v.netease.com/2017/cg/fxtpty.mp4"] localServerURL:[NSURL URLWithString:@"http://localhost:80/"]];
    
    _player.assetURL = proxyURL;
}

#pragma mark - SJLocalProxyServerDelegate

- (id<SJDataResponse>)server:(SJLocalProxyServer *)server responseWithRequest:(SJDataRequest *)request delegate:(id<SJDataResponseDelegate>)delegate {
    return [SJDataResponse.alloc initWithRequest:request delegate:delegate];
}

#pragma mark -

- (void)_startLocalProxyServer {
    _server = [SJLocalProxyServer.alloc initWithPort:80];
    _server.delegate = self;
    
    NSError *error = nil;
    if ( ![_server start:&error] ) {
        NSLog(@"启动失败: %@", error);
    }
}

- (void)_setupViews {
    _player = SJVideoPlayer.player;
}
@end
