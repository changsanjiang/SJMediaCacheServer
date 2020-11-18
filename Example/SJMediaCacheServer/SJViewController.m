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

#import <SJMediaCacheServer/NSURLRequest+MCS.h>
#import <SJMediaCacheServer/MCSURLRecognizer.h>
#import <SJMediaCacheServer/MCSPrefetcherManager.h>
#import <SJBaseVideoPlayer/SJAVMediaPlaybackController.h>

#import <MCSDownload.h>


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
     
    // play
    NSString *url = nil;
    url = @"http://hls.cntv.myalicdn.com/asp/hls/450/0303000a/3/default/bca293257d954934afadfaa96d865172/450.m3u8";
     url = @"https://dh2.v.netease.com/2017/cg/fxtpty.mp4";
    NSURL *URL = [NSURL URLWithString:url];
    [self _play:URL];
    
#pragma mark -
    
    // prefetch
    url = @"http://hls.cntv.myalicdn.com/asp/hls/450/0303000a/3/default/bca293257d954934afadfaa96d865172/450.m3u8";
    // url = @"https://dh2.v.netease.com/2017/cg/fxtpty.mp4";
    URL = [NSURL URLWithString:url];
    [self _prefetch:URL];
    
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [MCSDownload.shared cancelAllDownloadTasks];
    });
}

- (void)_play:(NSURL *)URL {
    NSURL *playbackURL = [SJMediaCacheServer.shared playbackURLWithURL:URL];
    // play
    _player.URLAsset = [SJVideoPlayerURLAsset.alloc initWithURL:playbackURL startPosition:0];
}

- (void)_prefetch:(NSURL *)URL {
    [SJMediaCacheServer.shared prefetchWithURL:URL preloadSize:20 * 1024 * 1024 progress:^(float progress) {
        
        // progress ...
        
    } completed:^(NSError * _Nullable error) {
        
        // complete ...
        
    }];
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
