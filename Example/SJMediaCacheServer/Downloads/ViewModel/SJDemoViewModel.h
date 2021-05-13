//
//  SJDemoViewModel.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/5/13.
//  Copyright © 2021 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SJDemoDownloadRow.h"
#import "SJDemoMediaRow.h"

NS_ASSUME_NONNULL_BEGIN

@interface SJDemoViewModel : NSObject

@property (nonatomic, copy, nullable) void(^mediaRowWasTappedExecuteBlock)(SJDemoMediaRow *row, NSIndexPath *indexPath);
@property (nonatomic, copy, nullable) void(^downloadRowWasTappedExecuteBlock)(SJDemoDownloadRow *row, NSIndexPath *indexPath);

- (nullable SJDemoMediaRow *)addMediaRowWithModel:(SJDemoMediaModel *)model;
- (nullable SJDemoDownloadRow *)addDownloadRowWithModel:(SJDemoMediaModel *)model;
- (void)removeRow:(SJDemoRow *)row;

@property (nonatomic, readonly) NSInteger numberOfSections;

- (NSInteger)numberOfRowsInSection:(NSInteger)section;
- (nullable NSString *)titleForHeaderInSection:(NSInteger)section;
- (nullable SJDemoRow *)rowAtIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
@end

NS_ASSUME_NONNULL_END
