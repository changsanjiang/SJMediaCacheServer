//
//  MCSExporterManager.h
//  SJMediaCacheServer
//
//  Created by BD on 2021/3/10.
//

#import <Foundation/Foundation.h>
#import "MCSInterfaces.h"
#import "MCSExporterDefines.h"

NS_ASSUME_NONNULL_BEGIN
@interface MCSExporterManager : NSObject<MCSExporterManager>
+ (instancetype)shared;

- (void)registerObserver:(id<MCSExportObserver>)observer;
- (void)removeObserver:(id<MCSExportObserver>)observer;

@property (nonatomic) NSInteger maxConcurrentExportCount;

@property (nonatomic, strong, readonly, nullable) NSArray<id<MCSExporter>> *allExporters;

@property (nonatomic, readonly) UInt64 countOfBytesAllExportedAssets;
 
- (nullable id<MCSExporter>)exportAssetWithURL:(NSURL *)URL;
- (void)removeAssetWithURL:(NSURL *)URL;
- (void)removeAllAssets;
 
- (MCSExportStatus)statusForURL:(NSURL *)URL;
- (float)progressForURL:(NSURL *)URL; 
 
- (void)synchronizeProgressForExporterWithURL:(NSURL *)URL;
- (void)synchronize;

- (nullable NSArray<id<MCSExporter>> *)exportersForMask:(MCSExportStatusQueryMask)mask;
@end
NS_ASSUME_NONNULL_END
