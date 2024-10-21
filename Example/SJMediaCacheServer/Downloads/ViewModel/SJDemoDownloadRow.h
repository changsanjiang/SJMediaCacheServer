//
//  SJDemoDownloadRow.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/5/13.
//  Copyright © 2021 changsanjiang@gmail.com. All rights reserved.
//
 
#import "SJDemoRow.h"
#import <SJMediaCacheServer/SJMediaCacheServer.h>
#import "SJDemoDownloadCell.h"
#import "SJDemoMediaModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface SJDemoDownloadRow : SJDemoRow
- (instancetype)initWithMedia:(SJDemoMediaModel *)media;

@property (nonatomic, copy, nullable) void(^selectedExecuteBlock)(SJDemoDownloadRow *row, NSIndexPath *indexPath);

@property (nonatomic, strong, readonly) id<MCSExporter> exporter;
@property (nonatomic, strong, readonly) NSURL *URL;
@property (nonatomic, strong, readonly) NSString *name;

- (void)bindCell:(SJDemoDownloadCell *)cell atIndexPath:(NSIndexPath *)indexPath;
- (void)unbindCell:(SJDemoDownloadCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end

NS_ASSUME_NONNULL_END
