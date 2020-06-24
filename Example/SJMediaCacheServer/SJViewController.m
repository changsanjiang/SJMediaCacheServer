//
//  SJViewController.m
//  SJMediaCacheServer
//
//  Created by changsanjiang@gmail.com on 05/30/2020.
//  Copyright (c) 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJViewController.h"
#import <SJVideoPlayer/SJVideoPlayer.h>
#import <Masonry/Masonry.h>

#import "SJMediaCacheServer.h"
#import "MCSLogger.h"
 

@interface SJViewController ()
@property (nonatomic, strong, nullable) SJVideoPlayer *player;
@end

@implementation SJViewController

- (BOOL)shouldAutorotate {
    return NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self _setupViews];
    
    SJMediaCacheServer.shared.enabledConsoleLog = YES;
    
    NSURL *URL = [NSURL URLWithString:@"http://m3u8.soyoung.com/b4e47ebb6140c140ee504f27e35127db_02c3f06a.m3u8?sign=2d7bf820de50b502efb099abf7cbb6c0&t=5ef2e5e0"];
    
//    URL = [NSURL URLWithString:@"https://dh2.v.netease.com/2017/cg/fxtpty.mp4"];
    
    // playback URL
    NSURL *playbackURL = [SJMediaCacheServer.shared playbackURLWithURL:URL];
    
    // play
    _player.URLAsset = [SJVideoPlayerURLAsset.alloc initWithURL:playbackURL startPosition:0];
    
    
//    // 预加载
//    [SJMediaCacheServer.shared prefetchWithURL:URL preloadSize:20 * 1024 * 1024 progress:^(float progress) {
//        NSLog(@"%lf", progress);
//    } completed:^(NSError * _Nullable error) {
//        NSLog(@"%@", error);
//    }];
}

- (void)_setupViews {
    _player = SJVideoPlayer.player;
    _player.pauseWhenAppDidEnterBackground = NO;
    [self.view addSubview:_player.view];
    [_player.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.offset(0);
        make.centerY.offset(0);
        make.height.offset(210);
    }];
}
@end
