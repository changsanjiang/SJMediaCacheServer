//
//  MCSResourceManager.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDefines.h"
#import "MCSURLConvertor.h"
@class MCSVODResource, MCSVODReader, MCSVODResourcePartialContent;

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
///     If 0, there is no expiring limit.  The default value is 0.
///
@property (nonatomic) NSTimeInterval maxDiskAgeForResource;

/// The maximum length of free disk space the device should reserved, in bytes.
///
///     When the free disk space of device is less than or equal to this value, unread resources will be removed.
///
///     If 0, there is no disk space limit. The default value is 0.
///
@property (nonatomic) NSUInteger reservedFreeDiskSpace;

/// Empties the cache. This method may blocks the calling thread until file delete finished.
///
- (void)removeAllResources;

- (id<MCSResource>)resourceWithURL:(NSURL *)URL;
- (void)update:(id<MCSResource>)resource;
- (void)reader:(MCSVODReader *)reader willReadResource:(id<MCSResource>)resource;
- (void)reader:(MCSVODReader *)reader didEndReadResource:(id<MCSResource>)resource;
- (void)didWriteDataForResource:(id<MCSResource>)resource;
@end

NS_ASSUME_NONNULL_END
