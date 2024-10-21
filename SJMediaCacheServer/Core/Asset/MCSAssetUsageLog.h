//
//  MCSAssetUsageLog.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSInterfaces.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSAssetUsageLog : NSObject<MCSSaveable>
- (instancetype)initWithAsset:(id<MCSAsset>)asset;
@property (nonatomic, readonly) NSInteger id;
@property (nonatomic, readonly) NSInteger asset; // associated asset id
@property (nonatomic, readonly) MCSAssetType assetType;
// removed
//@property (nonatomic, readonly) NSUInteger usageCount;
// The updatedTime has been changed to lastReadTime, representing the time of the last read.
@property (nonatomic, readonly) NSTimeInterval updatedTime;
@property (nonatomic, readonly) NSTimeInterval createdTime;

@property (nonatomic, readonly) BOOL isUpdated;
- (void)updateLastReadTime:(NSTimeInterval)lastReadTime;
- (void)completeSync;
@end

NS_ASSUME_NONNULL_END
