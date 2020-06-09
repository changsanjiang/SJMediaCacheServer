//
//  MCSResource.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDefines.h"
@class MCSResourceUsageLog;

NS_ASSUME_NONNULL_BEGIN

@interface MCSResource : NSObject<MCSResource>
@property (nonatomic, readonly) MCSResourceType type;

- (id<MCSResourceReader>)readerWithRequest:(NSURLRequest *)request;
- (id<MCSResourcePrefetcher>)prefetcherWithRequest:(NSURLRequest *)request;

@property (nonatomic, strong, readonly) MCSResourceUsageLog *log;
@end

NS_ASSUME_NONNULL_END
