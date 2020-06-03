//
//  SJResource.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJMediaCacheServerDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SJResource : NSObject<SJResource>
+ (instancetype)resourceWithURL:(NSURL *)URL;

- (id<SJResourceReader>)readDataWithRequest:(id<SJDataRequest>)request;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
