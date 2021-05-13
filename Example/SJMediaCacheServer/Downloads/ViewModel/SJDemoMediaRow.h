//
//  SJDemoMediaRow.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/5/13.
//  Copyright © 2021 changsanjiang@gmail.com. All rights reserved.
//

#import "SJDemoRow.h"
#import "SJDemoMediaModel.h"
#import "SJDemoMediaTableViewCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface SJDemoMediaRow : SJDemoRow
- (instancetype)initWithMedia:(SJDemoMediaModel *)media;

@property (nonatomic, strong, readonly) SJDemoMediaModel *media;

@property (nonatomic, copy, nullable) void(^selectedExecuteBlock)(SJDemoMediaRow *row, NSIndexPath *indexPath);

@property (nonatomic, strong, readonly) NSURL *URL;
@property (nonatomic, strong, readonly) NSString *name;

- (void)bindCell:(SJDemoMediaTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
- (void)unbindCell:(SJDemoMediaTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end

NS_ASSUME_NONNULL_END
