//
//  MCSResource.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSResource : NSObject<MCSResource>
@property (nonatomic, readonly) MCSResourceType type;

- (id<MCSResourceReader>)readerWithRequest:(NSURLRequest *)request;
- (id<MCSResourcePrefetcher>)prefetcherWithRequest:(NSURLRequest *)request;

@property (nonatomic, readonly) NSInteger numberOfCumulativeUsage; ///< 累计被使用次数
@property (nonatomic, readonly) NSTimeInterval updatedTime;        ///< 最后一次更新时的时间
@property (nonatomic, readonly) NSTimeInterval createdTime;        ///< 创建时间
@end

NS_ASSUME_NONNULL_END
