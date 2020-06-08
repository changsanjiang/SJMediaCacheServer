//
//  MCSResource.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDefines.h"
@class MCSResourcePartialContent;

NS_ASSUME_NONNULL_BEGIN

@interface MCSResource : NSObject<MCSResource>
+ (instancetype)resourceWithURL:(NSURL *)URL;

- (id<MCSResourceReader>)readerWithRequest:(MCSDataRequest *)request;

- (id<MCSResourcePrefetcher>)prefetcherWithRequest:(MCSDataRequest *)request;
@end
NS_ASSUME_NONNULL_END
