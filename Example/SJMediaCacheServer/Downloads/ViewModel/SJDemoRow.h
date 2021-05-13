//
//  SJDemoRow.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/5/13.
//  Copyright © 2021 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SJDemoRow : NSObject
@property (nonatomic, copy, nullable) void(^selectedExecuteBlock)(__kindof SJDemoRow *row, NSIndexPath *indexPath);

@property (nonatomic, readonly) Class cellClass;
@property (nonatomic, strong, readonly, nullable) UINib *cellNib;

- (void)bindCell:(__kindof UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
- (void)unbindCell:(__kindof UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end

NS_ASSUME_NONNULL_END
