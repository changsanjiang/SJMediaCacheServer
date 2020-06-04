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
- (void)setContentType:(NSString *)contentType;
- (void)setTotalLength:(NSUInteger)totalLength;
@end

NS_ASSUME_NONNULL_END
