//
//  MCSResourceManager.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCSURLConvertor.h"
@class MCSResource, MCSResourceReader, MCSResourcePartialContent;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSNotificationName const MCSResourceManagerWillRemoveResourceNotification;
FOUNDATION_EXTERN NSString *MCSResourceManagerUserInfoResourceKey;

@interface MCSResourceManager : NSObject
+ (instancetype)shared;

@property (nonatomic, strong, readonly) MCSURLConvertor *convertor;

/// default value is 20;
@property (nonatomic) NSUInteger cacheCountLimit;

- (MCSResource *)resourceWithURL:(NSURL *)URL;

/// 将更新的数据同步到数据库中
- (void)update:(MCSResource *)resource;

- (void)reader:(MCSResourceReader *)reader willReadResource:(MCSResource *)resource;
- (void)reader:(MCSResourceReader *)reader didEndReadResource:(MCSResource *)resource;

/// 删除当前未被使用, 并且最近更新时间与使用次数最少的资源
///
- (void)removeEldestResourcesIfNeeded;

/// 移除全部资源
///
///     注意正在使用的资源也会被删除
///
- (void)removeAllResources;
@end

NS_ASSUME_NONNULL_END
