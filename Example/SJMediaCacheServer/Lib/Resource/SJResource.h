//
//  SJResource.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJMediaCacheServerDefines.h"
@protocol SJResourceDelegate;
@class SJResourcePartialContent;

NS_ASSUME_NONNULL_BEGIN

@interface SJResource : NSObject<SJResource>
+ (instancetype)resourceWithURL:(NSURL *)URL;

- (id<SJResourceReader>)readDataWithRequest:(SJDataRequest *)request;

#pragma mark -

@property (nonatomic, copy, readonly) NSString *name;

@property (nonatomic, weak, nullable) id<SJResourceDelegate> delegate;

- (NSString *)filePathOfContent:(SJResourcePartialContent *)content;

- (SJResourcePartialContent *)createContentWithOffset:(NSUInteger)offset;

@property (nonatomic, readonly) NSUInteger totalLength;

@property (nonatomic, copy, readonly, nullable) NSString *contentType;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

@protocol SJResourceDelegate <NSObject>
- (void)resource:(SJResource *)resource contentTypeDidChange:(NSString *)contentType;
- (void)resource:(SJResource *)resource totalLengthDidChange:(NSUInteger)totalLength;
@end
NS_ASSUME_NONNULL_END
