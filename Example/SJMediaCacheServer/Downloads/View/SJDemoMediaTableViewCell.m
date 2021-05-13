//
//  SJDemoMediaTableViewCell.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/5/13.
//  Copyright © 2021 changsanjiang@gmail.com. All rights reserved.
//

#import "SJDemoMediaTableViewCell.h"

@interface SJDemoMediaTableViewCell ()
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;

@end

@implementation SJDemoMediaTableViewCell

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
@end
