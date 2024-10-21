//
//  MCSAssetExporter.m
//  SJMediaCacheServer
//
//  Created by db on 2024/10/21.
//

#import "MCSAssetExporter.h"
#import "MCSPrefetcherManager.h"
#import "MCSAssetManager.h"
#import "MCSCacheManager.h"
#import "FILEAsset.h"
#import "HLSAsset.h"
#import "MCSError.h"

@interface MCSAssetExporter () {
    id<MCSPrefetchTask> _task;
}
@property (nonatomic) NSInteger id;
@property (nonatomic, strong) NSString *name; // asset name
@property (nonatomic) MCSAssetType type;
@property (nonatomic, strong) NSString *URLString;
@end

@implementation MCSAssetExporter
@synthesize URL = _URL;
@synthesize status = _status;
@synthesize progress = _progress;
@synthesize progressDidChangeExecuteBlock = _progressDidChangeExecuteBlock;
@synthesize statusDidChangeExecuteBlock = _statusDidChangeExecuteBlock;

- (instancetype)initWithURLString:(NSString *)URLStr name:(NSString *)name type:(MCSAssetType)type {
    self = [self init];
    if ( self ) {
        _URLString = URLStr;
        _name = name;
        _type = type;
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if ( self ) {
        _status = MCSAssetExportStatusSuspended;
    }
    return self;
}

+ (NSString *)sql_primaryKey {
    return @"id";
}

+ (NSArray<NSString *> *)sql_autoincrementlist {
    return @[self.sql_primaryKey];
}

+ (NSArray<NSString *> *)sql_blacklist {
    return @[@"URL", @"progress"];
}

- (NSURL *)URL {
    @synchronized (self) {
        if ( _URL == nil ) _URL = [NSURL URLWithString:_URLString];
        return _URL;
    }
}
  
- (MCSAssetExportStatus)status {
    @synchronized (self) {
        return _status;
    }
}

- (float)progress {
    @synchronized (self) {
        return _status == MCSAssetExportStatusFinished ? 1.0 : _progress;
    }
}

- (void)synchronize {
    @synchronized (self) {
        [self _syncProgress];
    }
}

- (void)resume {
    @synchronized (self) {
        switch ( _status ) {
            case MCSAssetExportStatusFinished:
            case MCSAssetExportStatusWaiting:
            case MCSAssetExportStatusExporting:
            case MCSAssetExportStatusCancelled:
                return;
            case MCSAssetExportStatusUnknown:
            case MCSAssetExportStatusFailed:
            case MCSAssetExportStatusSuspended: {
                _status = MCSAssetExportStatusWaiting;
                if ( _URL == nil ) _URL = [NSURL URLWithString:_URLString];
                __weak typeof(self) _self = self;
                _task = [MCSPrefetcherManager.shared prefetchWithURL:_URL progress:^(float progress) {
                    __strong typeof(_self) self = _self;
                    if ( self == nil ) return;
                    @synchronized (self) {
                        [self _syncProgress];
                    }
                } completed:^(NSError * _Nullable error) {
                    __strong typeof(_self) self = _self;
                    if ( self == nil ) return;
                    @synchronized (self) {
                        [self _prefetchDidCompleteWithError:error];
                    }
                }];
                _task.prefetchStartHandler = ^(id<MCSPrefetchTask>  _Nonnull task) {
                    __strong typeof(_self) self = _self;
                    if ( self == nil ) return;
                    @synchronized (self) {
                        [self _prefetchDidStart];
                    }
                };
                [self _notifyStatusChange];
            }
                return;
        }
    }
}

- (void)suspend {
    @synchronized (self) {
        switch ( _status ) {
            case MCSAssetExportStatusFinished:
            case MCSAssetExportStatusFailed:
            case MCSAssetExportStatusCancelled:
            case MCSAssetExportStatusSuspended:
                return;
            case MCSAssetExportStatusUnknown:
            case MCSAssetExportStatusWaiting:
            case MCSAssetExportStatusExporting: {
                _status = MCSAssetExportStatusSuspended;
                if ( _task != nil ) {
                    [_task cancel];
                    _task = nil;
                }
                [self _notifyStatusChange];
            }
        }
    }
}

- (void)cancel {
    @synchronized (self) {
        switch ( _status ) {
            case MCSAssetExportStatusFinished:
            case MCSAssetExportStatusCancelled:
                return;
            case MCSAssetExportStatusUnknown:
            case MCSAssetExportStatusFailed:
            case MCSAssetExportStatusSuspended:
            case MCSAssetExportStatusWaiting:
            case MCSAssetExportStatusExporting: {
                _status = MCSAssetExportStatusCancelled;
                if ( _task != nil ) {
                    [_task cancel];
                    _task = nil;
                }
                [self _notifyStatusChange];
                [self _notifyComplete:[NSError mcs_errorWithCode:MCSCancelledError userInfo:@{
                    MCSErrorUserInfoObjectKey : self,
                    MCSErrorUserInfoReasonKey : @"导出任务被取消了"
                }]];
            }
        }
    }
}

#pragma mark - unlocked

- (void)_prefetchDidStart {
    switch (_status) {
        case MCSAssetExportStatusWaiting: {
            _status = MCSAssetExportStatusExporting;
            [self _notifyStatusChange];
            [self _syncProgress];
        }
            break;
        case MCSAssetExportStatusUnknown:
        case MCSAssetExportStatusExporting:
        case MCSAssetExportStatusFinished:
        case MCSAssetExportStatusFailed:
        case MCSAssetExportStatusSuspended:
        case MCSAssetExportStatusCancelled:
            break;
    }
}

- (void)_prefetchDidCompleteWithError:(NSError *_Nullable)error {
    switch (_status) {
        case MCSAssetExportStatusExporting: {
            _status = error != nil ? MCSAssetExportStatusFailed : MCSAssetExportStatusFinished;
            _task = nil;
            if ( _status == MCSAssetExportStatusFinished ) {
                _progress = 1;
                [self _notifyProgressChange];
            }
            [self _notifyStatusChange];
            [self _notifyComplete:error];
        }
            break;
        case MCSAssetExportStatusUnknown:
        case MCSAssetExportStatusWaiting:
        case MCSAssetExportStatusFinished:
        case MCSAssetExportStatusFailed:
        case MCSAssetExportStatusSuspended:
        case MCSAssetExportStatusCancelled:
            break;
    }
}

- (void)_syncProgress {
    switch (_status) {
        case MCSAssetExportStatusExporting: {
            id<MCSAsset> asset = [MCSAssetManager.shared assetWithName:_name type:_type];
            float progress = _progress;
            progress = asset.completeness;
            if ( progress > _progress ) {
                _progress = progress;
                [self _notifyProgressChange];
            }
        }
            break;
        case MCSAssetExportStatusUnknown:
        case MCSAssetExportStatusWaiting:
        case MCSAssetExportStatusFinished:
        case MCSAssetExportStatusFailed:
        case MCSAssetExportStatusSuspended:
        case MCSAssetExportStatusCancelled:
            break;
    }
}

- (void)_notifyStatusChange {
    [_delegate exporter:self statusDidChange:_status];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( self.statusDidChangeExecuteBlock != nil ) self.statusDidChangeExecuteBlock(self);
    });
}

- (void)_notifyProgressChange {
    [_delegate exporter:self statusDidChange:_progress];
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( self.progressDidChangeExecuteBlock != nil ) self.progressDidChangeExecuteBlock(self);
    });
}

- (void)_notifyComplete:(nullable NSError *)error {
    [_delegate exporter:self didCompleteWithError:error];
}
@end
