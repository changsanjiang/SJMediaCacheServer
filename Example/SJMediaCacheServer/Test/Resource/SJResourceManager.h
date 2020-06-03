//
//  SJResourceManager.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
@class SJResource;

NS_ASSUME_NONNULL_BEGIN

@interface SJResourceManager : NSObject
+ (instancetype)shared;

- (SJResource *)resourceWithURL:(NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
