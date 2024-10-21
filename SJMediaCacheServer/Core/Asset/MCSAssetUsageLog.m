//
//  MCSAssetUsageLog.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSAssetUsageLog.h"

@interface MCSAssetUsageLog ()
@property (nonatomic) NSInteger id;
@property (nonatomic) NSInteger asset;
@property (nonatomic) MCSAssetType assetType;
//@property (nonatomic) NSUInteger usageCount;
// The updatedTime has been changed to lastReadTime, representing the time of the last read.
@property (nonatomic) NSTimeInterval updatedTime;
@property (nonatomic) NSTimeInterval createdTime;
@end

@implementation MCSAssetUsageLog {
    BOOL mUpdated;
}
- (instancetype)initWithAsset:(id<MCSAsset>)asset {
    self = [super init];
    if ( self ) {
        _asset = asset.id;
        _assetType = asset.type;
        _createdTime = NSDate.date.timeIntervalSince1970;
        _updatedTime = _createdTime;
    }
    return self;
}

+ (NSString *)sql_primaryKey {
    return @"id";
}

+ (NSArray<NSString *> *)sql_autoincrementlist {
    return @[@"id"];
}

- (BOOL)isUpdated {
    return mUpdated;
}
- (void)updateLastReadTime:(NSTimeInterval)lastReadTime {
    mUpdated = YES;
    _updatedTime = lastReadTime;
}
- (void)completeSync {
    mUpdated = NO;
}
@end
