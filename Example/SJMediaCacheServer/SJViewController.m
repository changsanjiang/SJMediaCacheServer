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

- (void)viewDidLoad {
    [super viewDidLoad];
    [self _setupViews];
    
    MCSLogger.shared.enabledConsoleLog = YES;
 
//    NSURL *proxyURL = [MCSURLRecognizer.shared proxyURLWithURL:[NSURL URLWithString:@"http://hls.cntv.myalicdn.com/asp/hls/2000/0303000a/3/default/bca293257d954934afadfaa96d865172/2000.m3u8"] localServerURL:[NSURL URLWithString:@"http://127.0.0.1:80/"]];
        
    NSURL *URL = [NSURL URLWithString:@"http://hls.cntv.myalicdn.com/asp/hls/2000/0303000a/3/default/bca293257d954934afadfaa96d865172/2000.m3u8"];
    
//    URL = [NSURL URLWithString:@"http://audio.cdn.lanwuzhe.com/14927701757134e92"];
    
//    URL = [NSURL URLWithString:@"http://cdn.half-room.com/lm2polchkxAAl6J7ZaCJciiO5fN8.m3u8?pm3u8/0&e=1591792296&token=tCieKPlW4J4EZifkbE7fu1kt-NS6PKZ6nNk5eCMA:sohMlpZUQ8MOwO8w1nestE_esgo="];
    
    // playback URL
    NSURL *playbackURL = [SJMediaCacheServer.shared playbackURLWithURL:URL];
    
    // play
    _player.URLAsset = [SJVideoPlayerURLAsset.alloc initWithURL:playbackURL startPosition:0];

    _player.pauseWhenAppDidEnterBackground = NO;

    [self.view addSubview:_player.view];
    [_player.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.offset(0);
        make.centerY.offset(0);
        make.height.offset(210);
    }];
 
//    NSURLRequest *request = [NSURLRequest.alloc initWithURL:[NSURL URLWithString:@"https://dh2.v.netease.com/2017/cg/fxtpty.mp4"] range:NSMakeRange(0, 5 * 1024 * 1024)];
//    _prefetcher = [[MCSResourceManager.shared resourceWithURL:[NSURL URLWithString:@"https://dh2.v.netease.com/2017/cg/fxtpty.mp4"]] prefetcherWithRequest:request];
//    [_prefetcher prepare];
    
//    NSMutableURLRequest *request = [NSMutableURLRequest.alloc initWithURL:[NSURL URLWithString:@"http://localhost:80/"]];
////    [request setValue:[NSString stringWithFormat:@"bytes=0-2"] forHTTPHeaderField:@"Range"];
//
//    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//        NSLog(@"");
//    }] resume];
}

- (void)_setupViews {
    _player = SJVideoPlayer.player;
}
@end
