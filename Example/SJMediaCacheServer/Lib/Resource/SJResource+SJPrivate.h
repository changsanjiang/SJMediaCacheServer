//
//  SJResource+SJPrivate.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/4.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResource.h"

NS_ASSUME_NONNULL_BEGIN

@interface SJResource (SJPrivate)
- (void)setServer:(NSString * _Nullable)server contentType:(NSString * _Nullable)contentType totalLength:(NSUInteger)totalLength;
@end

NS_ASSUME_NONNULL_END
