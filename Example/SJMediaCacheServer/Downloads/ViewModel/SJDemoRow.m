//
//  SJDemoRow.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/5/13.
//  Copyright © 2021 changsanjiang@gmail.com. All rights reserved.
//

#import "SJDemoRow.h"

@implementation SJDemoRow

- (Class)cellClass {
    @throw [NSException new];
}

- (UINib *)cellNib {
    @throw [NSException new];
}

- (void)bindCell:(__kindof UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    @throw [NSException new];
}

- (void)unbindCell:(__kindof UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    @throw [NSException new];
}
@end
