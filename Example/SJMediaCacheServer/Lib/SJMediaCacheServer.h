//
//  SJMediaCacheServer.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SJMediaCacheServer : NSObject
+ (instancetype)shared;

/// Convert the URL to the playback URL.
///
/// @param URL      An instance of NSURL that references a media resource.
///
/// @return         It may return the local cache file URL or HTTP proxy URL, but when there is no cache file and the proxy service is not running, it will return the parameter URL.
///
- (NSURL *)playbackURLWithURL:(NSURL *)URL;

@end

NS_ASSUME_NONNULL_END
