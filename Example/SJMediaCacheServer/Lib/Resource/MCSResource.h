//
//  MCSResource.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSResource : NSObject<MCSResource>
+ (instancetype)resourceWithURL:(NSURL *)URL;

- (id<MCSResourceReader>)readerWithRequest:(NSURLRequest *)request;

- (id<MCSResourcePrefetcher>)prefetcherWithRequest:(NSURLRequest *)request;
@end
NS_ASSUME_NONNULL_END
