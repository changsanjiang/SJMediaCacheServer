//
//  SJDemoPlayerViewController.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/5/13.
//  Copyright © 2021 changsanjiang@gmail.com. All rights reserved.
//

#import "SJDemoPlayerViewController.h"
#import <SJVideoPlayer/SJVideoPlayer.h>
#import <Masonry/Masonry.h>

@interface SJDemoPlayerViewController ()
@property (nonatomic, strong) SJVideoPlayer *player;
@end

@implementation SJDemoPlayerViewController {
    NSURL *_URL ;
}

- (instancetype)initWithURL:(NSURL *)URL {
    self = [super init];
    if ( self ) {
        _URL = URL;
    }
    return self;
}

- (BOOL)shouldAutorotate {
    return NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    
    
    _player = SJVideoPlayer.player;
    _player.URLAsset = [SJVideoPlayerURLAsset.alloc initWithURL:_URL];
    [self.view addSubview:_player.view];
    [_player.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.offset(0);
    }];
}

@end
