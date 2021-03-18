//
//  MCSAssetExportSession.h
//  SJMediaCacheServer
//
//  Created by BD on 2021/3/10.
//

#import <Foundation/Foundation.h>
#import "MCSInterfaces.h"
@protocol MCSAssetExportTask;

#warning next ...

NS_ASSUME_NONNULL_BEGIN
/// 将资源导出到`documentRootPath`目录下
@interface MCSAssetExportSession : NSObject
+ (instancetype)shared;

@property (nonatomic, copy, null_resettable) NSString *documentRootPath;

- (float)exportProgressForURL:(NSURL *)URL;
- (nullable NSURL *)playbackURLForExportedAssetWithURL:(NSURL *)URL;
- (nullable id<MCSAssetExportTask>)exportAssetWithURL:(NSURL *)URL;
@end

typedef NS_ENUM(NSUInteger, MCSAssetExportStatus) {
    MCSAssetExportStatusWaiting,
    MCSAssetExportStatusExporting,
    MCSAssetExportStatusFinished,
    MCSAssetExportStatusFailed,
    MCSAssetExportStatusSuspended,
    MCSAssetExportStatusCancelled,
};

@protocol MCSAssetExportTask <NSObject>
@property (nonatomic, strong, readonly, nullable) NSError *error;
@property (nonatomic, readonly) MCSAssetExportStatus status;
@property (nonatomic, readonly) float progress;
@property (nonatomic, copy, nullable) void(^progressCallback)(id<MCSAssetExportTask> task);
@property (nonatomic, copy, nullable) void(^statusDidChangeCallback)(id<MCSAssetExportTask> task);
- (void)resume;     // 恢复
- (void)suspend;    // 暂停, 不删除
- (void)cancel;     // 取消, 并删除
@end
NS_ASSUME_NONNULL_END
