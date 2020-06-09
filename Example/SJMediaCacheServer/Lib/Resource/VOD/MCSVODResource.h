//
//  MCSResource.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResource.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSVODResource : MCSResource
- (id<MCSResourceReader>)readerWithRequest:(NSURLRequest *)request;

- (id<MCSResourcePrefetcher>)prefetcherWithRequest:(NSURLRequest *)request;

@end
NS_ASSUME_NONNULL_END
