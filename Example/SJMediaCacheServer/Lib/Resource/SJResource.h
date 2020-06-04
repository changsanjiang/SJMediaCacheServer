//
//  SJResource.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJMediaCacheServerDefines.h"
@class SJResourcePartialContent;

NS_ASSUME_NONNULL_BEGIN

@interface SJResource : NSObject<SJResource>
+ (instancetype)resourceWithURL:(NSURL *)URL;

- (id<SJResourceReader>)readDataWithRequest:(SJDataRequest *)request;

#pragma mark -

@property (nonatomic, copy, readonly) NSString *name;

- (NSString *)filePathOfContent:(SJResourcePartialContent *)content;

- (SJResourcePartialContent *)createContentWithOffset:(NSUInteger)offset;

@property (nonatomic, copy, readonly, nullable) NSString *contentType;
@property (nonatomic, copy, readonly, nullable) NSString *server;
@property (nonatomic, readonly) NSUInteger totalLength;
@end
NS_ASSUME_NONNULL_END
