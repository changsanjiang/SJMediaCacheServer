//
//  MCSResourceManager.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCSURLConvertor.h"
@class MCSResource, MCSResourceReader, MCSResourcePartialContent;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSNotificationName const MCSResourceManagerWillRemoveResourceNotification;
FOUNDATION_EXTERN NSString *MCSResourceManagerUserInfoResourceKey;

@interface MCSResourceManager : NSObject
+ (instancetype)shared;

/// The maximum number of resources the cache should hold.
///
///     If 0, there is no count limit. The default value is 0.
///
///     This is not a strict limit—if the cache goes over the limit, a resource in the cache could be evicted instantly, later, or possibly never, depending on the usage details of the resource.
///
@property (nonatomic) NSUInteger cacheCountLimit;

/// The maximum length of time to keep a resource in the cache, in seconds.
///
///     The default value is 24h (24 * 60 * 60).
///
@property (nonatomic) NSTimeInterval maxDiskAgeForResource;

/// Empties the cache. This method may blocks the calling thread until file delete finished.
///
- (void)removeAllResources;

- (MCSResource *)resourceWithURL:(NSURL *)URL;
- (void)update:(MCSResource *)resource;
- (void)reader:(MCSResourceReader *)reader willReadResource:(MCSResource *)resource;
- (void)reader:(MCSResourceReader *)reader didEndReadResource:(MCSResource *)resource;
@end

NS_ASSUME_NONNULL_END
