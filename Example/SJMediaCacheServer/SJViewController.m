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
#import <AVKit/AVKit.h>

static NSString *const DEMO_URL = @"http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8";

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
    
    AVRoutePickerView *routePickerView = [[AVRoutePickerView alloc]initWithFrame:CGRectMake(40, 88, 40, 40)];
    [self.view addSubview:routePickerView];
}

- (IBAction)play:(id)sender {
#ifdef DEBUG
    NSLog(@"%d : %s", __LINE__, sel_getName(_cmd));
#endif
    
    NSURL *playbackURL = [SJMediaCacheServer.shared proxyURLFromURL:[NSURL URLWithString:DEMO_URL]];
    _player.URLAsset = [SJVideoPlayerURLAsset.alloc initWithURL:playbackURL startPosition:0];
}

@end
