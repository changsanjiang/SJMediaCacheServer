//
//  MCSVODPrefetcher.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/8.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDefines.h"
@class MCSVODResource;

NS_ASSUME_NONNULL_BEGIN

@interface MCSVODPrefetcher : NSObject<MCSResourcePrefetcher>
- (instancetype)initWithResource:(__weak MCSVODResource *)resource request:(NSURLRequest *)request;

@property (nonatomic, weak, nullable) id<MCSResourcePrefetcherDelegate> delegate;

@property (nonatomic, readonly) BOOL isPrepared;
@property (nonatomic, readonly) BOOL isFinished;
@property (nonatomic, readonly) BOOL isClosed;

- (void)prepare;
- (void)close;
@end

NS_ASSUME_NONNULL_END
