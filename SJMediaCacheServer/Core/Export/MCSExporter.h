//
//  MCSExporter.h
//  SJMediaCacheServer
//
//  Created by db on 2024/10/21.
//

#import "MCSExporterDefines.h"
#import "MCSInterfaces.h"
@protocol MCSExporterDelegate;

NS_ASSUME_NONNULL_BEGIN
@interface MCSExporter : NSObject<MCSSaveable, MCSExporter>
- (instancetype)initWithURLString:(NSString *)URLStr name:(NSString *)name type:(MCSAssetType)type;
@property (nonatomic, readonly) NSInteger id;
@property (nonatomic, strong, readonly) NSString *name; // asset name
@property (nonatomic, readonly) MCSAssetType type;
@property (nonatomic, strong, readonly) NSURL *URL;
@property (nonatomic) MCSExportStatus status;
@property (nonatomic) float progress;
@property (nonatomic, weak, nullable) id<MCSExporterDelegate> delegate;
- (void)synchronize;
- (void)resume;
- (void)suspend;
- (void)cancel;
@end

@protocol MCSExporterDelegate <NSObject>
- (void)exporter:(id<MCSExporter>)exporter statusDidChange:(MCSExportStatus)status;
- (void)exporter:(id<MCSExporter>)exporter didCompleteWithError:(nullable NSError *)error;
- (void)exporter:(id<MCSExporter>)exporter progressDidChange:(float)progress;
@end
NS_ASSUME_NONNULL_END
