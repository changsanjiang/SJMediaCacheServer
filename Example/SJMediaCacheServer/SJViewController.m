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

#import <SJMediaCacheServer/MCSUtils.h>
 
//#import <SJBaseVideoPlayer/SJAliMediaPlaybackController.h>


#import <SJMediaCacheServer/NSURLRequest+MCS.h>

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
    
//    _player.playbackController = SJAliMediaPlaybackController.new;

    SJMediaCacheServer.shared.enabledConsoleLog = YES;
    SJMediaCacheServer.shared.logOptions = MCSLogOptionSessionTask | MCSLogOptionPrefetcher;
    
}

- (IBAction)remove:(id)sender {
    [SJMediaCacheServer.shared removeAllCaches];
    NSString *url = @"https://videosy.soyoung.com/bf35d9c586c245e377ce86245fa51ed0.mp4";
    [SJMediaCacheServer.shared prefetchWithURL:[NSURL URLWithString:url] preloadSize:300 * 1024];
}

- (IBAction)test:(id)sender {

#pragma mark -
    
    NSString *url = nil;
    
    url = @"http://hls.cntv.myalicdn.com/asp/hls/450/0303000a/3/default/bca293257d954934afadfaa96d865172/450.m3u8";
//    url = @"http://video.youcheyihou.com/3240b282-6806-43c7-9c41-428d51a9fc1f.mp4";
    url = @"https://dh2.v.netease.com/2017/cg/fxtpty.mp4";
    url = @"https://videosy.soyoung.com/bf35d9c586c245e377ce86245fa51ed0.mp4";
//    url = @"http://vod.lanwuzhe.com/34bc457df21b44e9aaabef393d5c910f/bbbfabc5e6c744be9de4a3c87a65f71b-5287d2089db37e62345123a1be272f8b.mp4";
//    url = @"https://xy2.v.netease.com/r/video/20200629/b03eeb99-6eef-407d-9055-079b22796fdd.mp4";
    
    url = @"http://videosy.soyoung.com/750ac763738bcde017ab1c2344c78402_cefb1453.m3u8";
    
    NSURL *URL = [NSURL URLWithString:url];
    
    // playback URL
    NSURL *playbackURL = [SJMediaCacheServer.shared playbackURLWithURL:URL];
    
//        _player.playbackController = SJIJKMediaPlaybackController.new;
    
    // play
    _player.URLAsset = [SJVideoPlayerURLAsset.alloc initWithURL:playbackURL startPosition:0];
    _player.muted = YES;
    
    __auto_type time = MCSTimerStart();
    __block BOOL isStartedPlay = NO;
    _player.playbackObserver.timeControlStatusDidChangeExeBlock = ^(__kindof SJBaseVideoPlayer * _Nonnull player) {
        if ( player.isPlaying && !isStartedPlay ) {
            NSLog(@"after (%lf) seconds!!", MCSTimerMilePost(time));
            isStartedPlay = YES;
        }
    };
    
#pragma mark -
    
    //    url = @"http://hls.cntv.myalicdn.com/asp/hls/450/0303000a/3/default/bca293257d954934afadfaa96d865172/450.m3u8";
    ////    url = @"https://dh2.v.netease.com/2017/cg/fxtpty.mp4";
    //    URL = [NSURL URLWithString:url];
    //
    //    for ( NSInteger i = 0 ; i < 10 ; ++ i ) {
    //        // 预加载
    //        [SJMediaCacheServer.shared prefetchWithURL:URL preloadSize:1 * 1024 * 1024 progress:^(float progress) {
    //
    //            // progress ...
    //
    //        } completed:^(NSError * _Nullable error) {
    //
    //            // complete ...
    //
    //            if ( error != nil ) {
    //                NSLog(@"error: %@", error);
    //            }
    //            else {
    //                NSLog(@"done");
    //            }
    //        }];
    //
    //    }
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

//(lldb) po [reader response]
//MCSResourceResponse:<0x281fa0380> { responseHeaders: {
//    "Accept-Ranges" = bytes;
//    Connection = "keep-alive";
//    "Content-Length" = 60036248;
//    "Content-Range" = "bytes 0-60036247/60036248";
//    "Content-Type" = "video/mp4";
//    Server = "nginx/1.13.5";
//} };

//<NSHTTPURLResponse: 0x281366b60> { URL: https://xy2.v.netease.com/r/video/20200629/b03eeb99-6eef-407d-9055-079b22796fdd.mp4 } { Status Code: 206, Headers {
//    "Accept-Ranges" =     (
//        bytes
//    );
//    Age =     (
//        1736
//    );
//    "Cache-Control" =     (
//        "max-age=2592000"
//    );
//    Connection =     (
//        "keep-alive"
//    );
//    "Content-Length" =     (
//        60036248
//    );
//    "Content-Range" =     (
//        "bytes 0-60036247/60036248"
//    );
//    "Content-Type" =     (
//        "video/mp4"
//    );
//    Date =     (
//        "Sat, 22 Aug 2020 12:07:35 GMT"
//    );
//    Etag =     (
//        "\"0841d8f4d94ecf64942a3ec2cfcd45c6\""
//    );
//    Expires =     (
//        "Mon, 21 Sep 2020 11:38:39 GMT"
//    );
//    "Last-Modified" =     (
//        "Mon, 29 Jun 2020 07:21:41 GMT"
//    );
//    Server =     (
//        "nginx/1.13.5"
//    );
//    "X-Trace-ID" =     (
//        e1e8ea9e384de25450920fbc29f8fcb6
//    );
//    "X-Via" =     (
//        "1.1 PSzjjxdx9ve75:8 (Cdn Cache Server V2.0)[19 200 0], 1.1 PS-SHA-01fRU214:10 (Cdn Cache Server V2.0)[0 200 0]"
//    );
//    "ntes-trace-id" =     (
//        "7ba9dd0d1a3f615a:7ba9dd0d1a3f615a:0:1"
//    );
//    "x-amz-meta-s3cmd-attrs" =     (
//        "atime:1593415295/ctime:1593415295/gid:65534/gname:nogroup/md5:0841d8f4d94ecf64942a3ec2cfcd45c6/mode:33188/mtime:1593415295/uid:65534/uname:nobody"
//    );
//    "x-amz-request-id" =     (
//        "tx000000000000003ca4c10-005ef9c0aa-e6e560-hba1"
//    );
//} }
