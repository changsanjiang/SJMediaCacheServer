//
//  SJDemoDownloadCell.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/5/13.
//  Copyright © 2021 changsanjiang@gmail.com. All rights reserved.
//

#import "SJDemoDownloadCell.h"

@interface SJDemoDownloadCell ()
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@end

@implementation SJDemoDownloadCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setName:(nullable NSString *)name {
    _nameLabel.text = name;
}

- (nullable NSString *)name {
    return _nameLabel.text;
}

- (void)setStatus:(nullable NSString *)status {
    _statusLabel.text = status;
}
- (nullable NSString *)status {
    return _statusLabel.text;
}
@end
