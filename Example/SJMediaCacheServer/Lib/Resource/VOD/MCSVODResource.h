//
//  MCSResource.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResourceSubclass.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSVODResource : MCSResource

- (void)setServer:(NSString * _Nullable)server contentType:(NSString * _Nullable)contentType totalLength:(NSUInteger)totalLength;
- (MCSResourcePartialContent *)createContentWithOffset:(NSUInteger)offset;

@property (nonatomic, copy, readonly, nullable) NSString *contentType;
@property (nonatomic, copy, readonly, nullable) NSString *server;
@property (nonatomic, readonly) NSUInteger totalLength;

@end
NS_ASSUME_NONNULL_END
