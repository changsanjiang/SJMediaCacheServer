//
//  SJDemoMediaRow.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/5/13.
//  Copyright © 2021 changsanjiang@gmail.com. All rights reserved.
//

#import "SJDemoMediaRow.h"

@implementation SJDemoMediaRow {
    __weak SJDemoMediaTableViewCell *_cell;
}
@dynamic selectedExecuteBlock;

- (Class)cellClass {
    return SJDemoMediaTableViewCell.class;
}

- (nullable UINib *)cellNib {
    return [UINib nibWithNibName:NSStringFromClass(self.cellClass) bundle:nil];
}

- (instancetype)initWithMedia:(SJDemoMediaModel *)media {
    self = [super init];
    if ( self ) {
        _media = media;
        _name = media.name;
        _URL = [NSURL URLWithString:media.url];
    }
    return self;
}

- (void)bindCell:(SJDemoMediaTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    _cell = cell;
    _cell.name = _name;
}

- (void)unbindCell:(SJDemoMediaTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    _cell = nil;
}
@end
