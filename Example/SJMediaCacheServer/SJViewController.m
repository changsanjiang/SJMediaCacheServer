//
//  SJViewController.m
//  SJMediaCacheServer
//
//  Created by changsanjiang@gmail.com on 05/30/2020.
//  Copyright (c) 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJViewController.h"
#import <SJMediaCacheServer/SJMediaCacheServer.h>
#import <SJVideoPlayer/SJVideoPlayer.h>
#import <Masonry/Masonry.h>

static NSString *const DEMO_URL_FILE = @"https://xy2.v.netease.com/2024/0705/64ba5c013ee90db19d399f0255ab9103qt.mp4";

@interface SJViewController ()
@property (nonatomic, strong, nullable) SJVideoPlayer *player;
@end

@implementation SJViewController
- (BOOL)shouldAutorotate {
    return NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _player = SJVideoPlayer.player;
    _player.pauseWhenAppDidEnterBackground = NO;
    [self.view addSubview:_player.view];
    [_player.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.offset(0);
        make.centerY.offset(0);
        make.height.offset(210);
    }];
    
    SJMediaCacheServer.shared.enabledConsoleLog = YES;
}

- (IBAction)play:(id)sender {
    NSURL *playbackURL = [SJMediaCacheServer.shared proxyURLFromURL:[NSURL URLWithString:DEMO_URL_FILE]];
    _player.URLAsset = [SJVideoPlayerURLAsset.alloc initWithURL:playbackURL startPosition:0];
}
@end
