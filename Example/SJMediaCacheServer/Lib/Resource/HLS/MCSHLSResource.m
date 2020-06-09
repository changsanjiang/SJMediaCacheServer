//
//  MCSHLSResource.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSResource.h"
#import "MCSResourceManager.h"

@interface MCSHLSResource ()

@end

@implementation MCSHLSResource
+ (instancetype)resourceWithURL:(NSURL *)URL {
    return [MCSResourceManager.shared resourceWithURL:URL];
}
 
- (id<MCSResourceReader>)readerWithRequest:(NSURLRequest *)request {
    return nil;
}

- (id<MCSResourcePrefetcher>)prefetcherWithRequest:(NSURLRequest *)request {
    return nil;
}
@end
