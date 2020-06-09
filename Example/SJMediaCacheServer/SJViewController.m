//
//  SJViewController.m
//  SJMediaCacheServer
//
//  Created by changsanjiang@gmail.com on 05/30/2020.
//  Copyright (c) 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJViewController.h"
#import "MCSDefines.h"
#import "MCSLocalProxyServer.h"
#import <SJVideoPlayer/SJVideoPlayer.h>
#import <Masonry/Masonry.h>

#import "MCSDataResponse.h"
#import "MCSURLConvertor.h"
#import "MCSLogger.h"
#import "MCSResource.h"
#import "MCSResourceManager.h"
 
@interface SJViewController ()<MCSLocalProxyServerDelegate>
@property (nonatomic, strong, nullable) MCSLocalProxyServer *server;
@property (nonatomic, strong, nullable) SJVideoPlayer *player;
@property (nonatomic, strong, nullable) id<MCSResourcePrefetcher> prefetcher;
@end

@implementation SJViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self _setupViews];
    
    MCSLogger.shared.enabledConsoleLog = YES;

    // 播放
    
    [self _startLocalProxyServer];
    NSURL *proxyURL = [MCSURLConvertor.shared proxyURLWithURL:[NSURL URLWithString:@"http://rec.app.lanwuzhe.com/recordings/z1.lanwuzhe.24086472/1589864400_1589950800.m3u8"] localServerURL:[NSURL URLWithString:@"http://127.0.0.1:80/"]];

//    NSURL *proxyURL = [MCSURLConvertor.shared proxyURLWithURL:[NSURL URLWithString:@"http://audio.cdn.lanwuzhe.com/14927679510623923"] localServerURL:[NSURL URLWithString:@"http://localhost:80/"]];
 
    _player.URLAsset = [SJVideoPlayerURLAsset.alloc initWithURL:proxyURL startPosition:0];

    _player.pauseWhenAppDidEnterBackground = NO;

    [self.view addSubview:_player.view];
    [_player.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.offset(0);
        make.centerY.offset(0);
        make.height.offset(210);
    }];

    
    
//    MCSDataRequest *request = [MCSDataRequest.alloc initWithURL:[NSURL URLWithString:@"https://dh2.v.netease.com/2017/cg/fxtpty.mp4"] range:NSMakeRange(0, 5 * 1024 * 1024)];
//    _prefetcher = [[MCSResourceManager.shared resourceWithURL:[NSURL URLWithString:@"https://dh2.v.netease.com/2017/cg/fxtpty.mp4"]] prefetcherWithRequest:request];
//    [_prefetcher prepare];
    
//    NSMutableURLRequest *request = [NSMutableURLRequest.alloc initWithURL:proxyURL];
//    [request setValue:[NSString stringWithFormat:@"bytes=0-2"] forHTTPHeaderField:@"Range"];
//
//    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//        NSLog(@"");
//    }] resume];
}

#pragma mark - MCSLocalProxyServerDelegate

- (id<MCSDataResponse>)server:(MCSLocalProxyServer *)server responseWithRequest:(MCSDataRequest *)request delegate:(id<MCSDataResponseDelegate>)delegate {
    return [MCSDataResponse.alloc initWithRequest:request delegate:delegate];
}

#pragma mark -

- (void)_startLocalProxyServer {
    _server = [MCSLocalProxyServer.alloc initWithPort:80];
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
