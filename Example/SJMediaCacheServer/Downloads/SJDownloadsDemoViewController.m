//
//  SJDownloadsDemoViewController.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/5/13.
//  Copyright © 2021 changsanjiang@gmail.com. All rights reserved.
//

#import "SJDownloadsDemoViewController.h"
#import <Masonry/Masonry.h>
#import "SJDemoViewModel.h"
#import "SJDemoDownloadRow.h"
#import "SJDemoPlayerViewController.h"
  
@interface SJDownloadsDemoViewController ()<UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) SJDemoViewModel *viewModel;
@end

@implementation SJDownloadsDemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _viewModel = SJDemoViewModel.new;
    __weak typeof(self) _self = self;
    _viewModel.mediaRowWasTappedExecuteBlock = ^(SJDemoMediaRow * _Nonnull row, NSIndexPath *indexPath) {
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;
        [self _downloadForMediaRow:row];
    };
    _viewModel.downloadRowWasTappedExecuteBlock = ^(SJDemoDownloadRow * _Nonnull row, NSIndexPath *indexPath) {
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;
        // 暂停, 恢复或播放
        [self _pauseResumeOrPlay:row];
    };
    
    // test rows
    NSArray<SJDemoMediaModel *> *medias = @[
        [SJDemoMediaModel.alloc initWithId:1 name:@"咕叽咕叽" url:@"https://dh2.v.netease.com/2017/cg/fxtpty.mp4"],
        [SJDemoMediaModel.alloc initWithId:2 name:@"唧咕唧咕" url:@"https://crazynote.v.netease.com/2019/0811/6bc0a084ee8655bfb2fa31757a0570f4qt.mp4"],
        [SJDemoMediaModel.alloc initWithId:3 name:@"可乐可乐" url:@"https://dhxy.v.netease.com/2019/0813/d792f23a8da810e73625a155f44a5d96qt.mp4"],
    ];
    
    for ( SJDemoMediaModel *media in medias ) {
        [_viewModel addMediaRowWithModel:media];
    }
    
    [self _setupViews];
}

#pragma mark - UITableViewDataSource, UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _viewModel.numberOfSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_viewModel numberOfRowsInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [_viewModel tableView:tableView cellForRowAtIndexPath:indexPath];;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(SJDemoDownloadCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [[_viewModel rowAtIndexPath:indexPath] bindCell:cell atIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(SJDemoDownloadCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [[_viewModel rowAtIndexPath:indexPath] unbindCell:cell atIndexPath:indexPath];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [_viewModel titleForHeaderInSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SJDemoRow *row = [_viewModel rowAtIndexPath:indexPath];
    row.selectedExecuteBlock(row, indexPath);
}

#pragma mark - mark

- (void)_setupViews {
    self.view.backgroundColor = UIColor.whiteColor;
    
    _tableView = [UITableView.alloc initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [self.view addSubview:_tableView];
    [_tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.offset(0);
    }];
}

- (void)_pauseResumeOrPlay:(SJDemoDownloadRow *)row {
    // 这里异步调用, 防止阻塞主线程
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        id<MCSAssetExporter> exporter = row.exporter;
        switch ( exporter.status ) {
            case MCSAssetExportStatusUnknown:
            case MCSAssetExportStatusFailed:
            case MCSAssetExportStatusSuspended:
                [exporter resume];
                break;
            case MCSAssetExportStatusWaiting:
            case MCSAssetExportStatusExporting:
                [exporter suspend];
                break;
            case MCSAssetExportStatusCancelled:
                break;
            case MCSAssetExportStatusFinished: {
                // 下载完成后, 获取播放地址进行播放
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSURL *playbackURL = [SJMediaCacheServer.shared playbackURLForExportedAssetWithURL:exporter.URL];
                    SJDemoPlayerViewController *vc = [SJDemoPlayerViewController.alloc initWithURL:playbackURL];
                    [self presentViewController:vc animated:YES completion:nil];
                });
            }
                break;
        }
    });
}

- (void)_downloadForMediaRow:(SJDemoMediaRow *)row {
    SJDemoMediaModel *model = row.media;
    [_viewModel removeRow:row];
    SJDemoDownloadRow *downloadRow = [_viewModel addDownloadRowWithModel:model];
    // 这里异步调用, 防止阻塞主线程
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [downloadRow.exporter resume];
    });
    [_tableView reloadData];
    
    
    ///
    /// 可以将`media`保存到你的数据库中
    ///
}
@end
