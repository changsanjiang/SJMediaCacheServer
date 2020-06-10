//
//  MCSHLSResource.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResource.h"
@class MCSResourcePartialContent;

NS_ASSUME_NONNULL_BEGIN
@interface MCSHLSResource : MCSResource
- (id<MCSResourceReader>)readerWithRequest:(NSURLRequest *)request;

- (id<MCSResourcePrefetcher>)prefetcherWithRequest:(NSURLRequest *)request;

@end
NS_ASSUME_NONNULL_END
