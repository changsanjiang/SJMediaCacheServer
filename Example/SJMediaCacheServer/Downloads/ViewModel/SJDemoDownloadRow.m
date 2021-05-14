//
//  SJDemoDownloadRow.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/5/13.
//  Copyright © 2021 changsanjiang@gmail.com. All rights reserved.
//

#import "SJDemoDownloadRow.h"

@interface SJDemoDownloadRow ()<MCSAssetExportObserver>

@end

@implementation SJDemoDownloadRow {
    __weak SJDemoDownloadCell *_cell;
}
@dynamic selectedExecuteBlock;

- (instancetype)initWithMedia:(SJDemoMediaModel *)media {
    self = [super init];
    if ( self ) {
        [SJMediaCacheServer.shared registerExportObserver:self];
        _name = media.name;
        _URL = [NSURL URLWithString:media.url];
        _exporter = [SJMediaCacheServer.shared exportAssetWithURL:_URL];
        
        // 这里异步同步进度, 防止阻塞主线程
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [self->_exporter synchronize];
        });
    }
    return self;
}

- (void)dealloc {
    [SJMediaCacheServer.shared removeExportObserver:self];
}

#pragma mark - MCSAssetExportObserver

- (void)exporter:(id<MCSAssetExporter>)exporter statusDidChange:(MCSAssetExportStatus)status {
    if ( exporter == _exporter ) {
        [self _refreshCell];
    }
}

- (void)exporter:(id<MCSAssetExporter>)exporter progressDidChange:(float)progress {
    if ( exporter == _exporter ) {
        [self _refreshCell];
    }
}

#pragma mark - mark


- (Class)cellClass {
    return SJDemoDownloadCell.class;
}

- (nullable UINib *)cellNib {
    return [UINib nibWithNibName:NSStringFromClass(self.cellClass) bundle:nil];
}

- (void)bindCell:(SJDemoDownloadCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    _cell = cell;
    [self _refreshCell];
}

- (void)unbindCell:(SJDemoDownloadCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    _cell = nil;
}

#pragma mark - mark

- (void)_refreshCell {
    _cell.name = _name;
    
    NSString *statusStr = nil;
    switch ( _exporter.status ) {
        case MCSAssetExportStatusUnknown:
            statusStr = @"Unknown";
            break;
        case MCSAssetExportStatusWaiting:
            statusStr = @"Waiting";
            break;
        case MCSAssetExportStatusExporting:
            statusStr = @"Exporting";
            break;
        case MCSAssetExportStatusFinished:
            statusStr = @"Finished(点击播放)";
            break;
        case MCSAssetExportStatusFailed:
            statusStr = @"Failed";
            break;
        case MCSAssetExportStatusSuspended:
            statusStr = @"Suspended";
            break;
        case MCSAssetExportStatusCancelled:
            statusStr = @"Cancelled";
            break;
    }
    _cell.status = [NSString stringWithFormat:@"%@: %.02lf", statusStr, _exporter.progress];
}
@end
