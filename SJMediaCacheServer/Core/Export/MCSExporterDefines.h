//
//  MCSExporterDefines.h
//  Pods
//
//  Created by BD on 2021/3/20.
//

#ifndef MCSExporterDefines_h
#define MCSExporterDefines_h

#import <Foundation/Foundation.h>
@protocol MCSExporter, MCSExportObserver, MCSExporterManager;

typedef NS_ENUM(NSUInteger, MCSExportStatus) {
    MCSExportStatusUnknown,
    MCSExportStatusWaiting,
    MCSExportStatusExporting,
    MCSExportStatusFinished,
    MCSExportStatusFailed,
    MCSExportStatusSuspended,
    MCSExportStatusCancelled,
};

typedef NS_OPTIONS(NSUInteger, MCSExportStatusQueryMask) {
    MCSExportStatusQueryMaskUnknown     = 1 << MCSExportStatusUnknown,
    MCSExportStatusQueryMaskWaiting     = 1 << MCSExportStatusWaiting,
    MCSExportStatusQueryMaskExporting   = 1 << MCSExportStatusExporting,
    MCSExportStatusQueryMaskFinished    = 1 << MCSExportStatusFinished,
    MCSExportStatusQueryMaskFailed      = 1 << MCSExportStatusFailed,
    MCSExportStatusQueryMaskSuspended   = 1 << MCSExportStatusSuspended,
    MCSExportStatusQueryMaskCancelled   = 1 << MCSExportStatusCancelled,
};

NS_ASSUME_NONNULL_BEGIN
@protocol MCSExporterManager <NSObject>
- (void)registerObserver:(id<MCSExportObserver>)observer;
- (void)removeObserver:(id<MCSExportObserver>)observer;

@property (nonatomic) NSInteger maxConcurrentExportCount;

@property (nonatomic, strong, readonly, nullable) NSArray<id<MCSExporter>> *allExporters;

- (nullable NSArray<id<MCSExporter>> *)exportersForMask:(MCSExportStatusQueryMask)mask;

- (nullable id<MCSExporter>)exportAssetWithURL:(NSURL *)URL;
- (void)removeAssetWithURL:(NSURL *)URL;
- (void)removeAllAssets;
 
- (MCSExportStatus)statusForURL:(NSURL *)URL;
- (float)progressForURL:(NSURL *)URL;

- (void)synchronizeProgressForExporterWithURL:(NSURL *)URL;
- (void)synchronize;
@end

@protocol MCSExporter <NSObject>
@property (nonatomic, strong, readonly) NSURL *URL;
@property (nonatomic, readonly) MCSExportStatus status;
@property (nonatomic, readonly) float progress;
- (void)synchronize; // 同步进度(由于存在边播边缓存, 导出进度可能会发生变动)
- (void)resume;      // 恢复
- (void)suspend;     // 暂停, 缓存文件不会被删除
- (void)cancel;      // 取消, 缓存可能会被资源管理器删除

@property (nonatomic, copy, nullable) void(^progressDidChangeExecuteBlock)(id<MCSExporter> exporter);
@property (nonatomic, copy, nullable) void(^statusDidChangeExecuteBlock)(id<MCSExporter> exporter);
@end

@protocol MCSExportObserver <NSObject>
@optional
- (void)exporter:(id<MCSExporter>)exporter statusDidChange:(MCSExportStatus)status;
- (void)exporter:(id<MCSExporter>)exporter failedWithError:(nullable NSError *)error;
- (void)exporter:(id<MCSExporter>)exporter progressDidChange:(float)progress;
- (void)exporterManager:(id<MCSExporterManager>)manager didRemoveAssetWithURL:(NSURL *)URL;
- (void)exporterManagerDidRemoveAllAssets:(id<MCSExporterManager>)manager;
@end


NS_ASSUME_NONNULL_END
#endif /* MCSExporterDefines_h */
