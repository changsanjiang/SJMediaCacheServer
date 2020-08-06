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
    SJMediaCacheServer.shared.logOptions = MCSLogOptionDownload;
    
#pragma mark -
    
    NSString *url = nil;
    
    url = @"https://yunke.zto.com/api/common/mu/getMyM3u8.m3u8?courseWareId=6420832&key=s5VcBNQ3pEMOkP1EteNxWH5W83B9fsEhY5PmvciNYK5mBsxiw1c0c4eLR7c2QVQ%2Bu4%2BcbY%2FXsbMMW%2BU75LbUhHqXGvSW%2BZZNAQSfaqcybCZruN2FztypfZifUy3UKHCrbUSMDQRBhFeLjIOcFUjQGFMrzXDd1I8QiVI9TR0MpZIF%2B8IbaUsBvK7F4oQeICbfXe2%2Fvmy9W2f%2BLE7ch%2B0JjazjyGDb8goeuXjDwkz7yAY126d%2BQ%2BBy5azxQYlO9V90xaGLlv9mEKGzW%2FijWKKFJ8LsxM%2FFQQ5Wc1Z23Z%2Fynn%2FWmAjdZFMhidtAdKu6Kb%2F61eqZs%2BZYqCyRRTsZwXu6d%2B0wyckpuu6VX6J4eWFXwJ******";
//    url = @"https://dh2.v.netease.com/2017/cg/fxtpty.mp4";
    
    NSURL *URL = [NSURL URLWithString:url];

    // playback URL
    NSURL *playbackURL = [SJMediaCacheServer.shared playbackURLWithURL:URL];

    // play
    _player.URLAsset = [SJVideoPlayerURLAsset.alloc initWithURL:playbackURL startPosition:50];
    
//#pragma mark -
//    
////    url = @"http://hls.cntv.myalicdn.com/asp/hls/450/0303000a/3/default/bca293257d954934afadfaa96d865172/450.m3u8";
////    url = @"https://dh2.v.netease.com/2017/cg/fxtpty.mp4";
//    URL = [NSURL URLWithString:url];
//
//    // 预加载
//    [SJMediaCacheServer.shared prefetchWithURL:URL preloadSize:1 * 1024 * 1024 progress:^(float progress) {
//
//        // progress ...
//
//    } completed:^(NSError * _Nullable error) {
//
//        // complete ...
//
//        if ( error != nil ) {
//            NSLog(@"error: %@", error);
//        }
//        else {
//            NSLog(@"done");
//        }
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
