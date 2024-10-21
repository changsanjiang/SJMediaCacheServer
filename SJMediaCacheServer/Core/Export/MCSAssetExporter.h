//
//  MCSAssetExporter.h
//  SJMediaCacheServer
//
//  Created by db on 2024/10/21.
//

#import "MCSAssetExporterDefines.h"
#import "MCSInterfaces.h"
@protocol MCSAssetExporterDelegate;

NS_ASSUME_NONNULL_BEGIN
@interface MCSAssetExporter : NSObject<MCSSaveable, MCSAssetExporter>
- (instancetype)initWithURLString:(NSString *)URLStr name:(NSString *)name type:(MCSAssetType)type;
@property (nonatomic, readonly) NSInteger id;
@property (nonatomic, strong, readonly) NSString *name; // asset name
@property (nonatomic, readonly) MCSAssetType type;
@property (nonatomic, strong, readonly) NSURL *URL;
@property (nonatomic) MCSAssetExportStatus status;
@property (nonatomic) float progress;
@property (nonatomic, weak, nullable) id<MCSAssetExporterDelegate> delegate;
- (void)synchronize;
- (void)resume;
- (void)suspend;
- (void)cancel;
@end

@protocol MCSAssetExporterDelegate <NSObject>
- (void)exporter:(id<MCSAssetExporter>)exporter statusDidChange:(MCSAssetExportStatus)status;
- (void)exporter:(id<MCSAssetExporter>)exporter didCompleteWithError:(nullable NSError *)error;
- (void)exporter:(id<MCSAssetExporter>)exporter progressDidChange:(float)progress;
@end
NS_ASSUME_NONNULL_END
