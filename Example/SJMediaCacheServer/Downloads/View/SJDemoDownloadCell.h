//
//  SJDemoDownloadCell.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/5/13.
//  Copyright © 2021 changsanjiang@gmail.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SJMediaCacheServer/SJMediaCacheServer.h>

NS_ASSUME_NONNULL_BEGIN
@interface SJDemoDownloadCell : UITableViewCell
@property (nonatomic, strong, nullable) NSString *name;
@property (nonatomic, strong, nullable) NSString *status;
@end
NS_ASSUME_NONNULL_END
