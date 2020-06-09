//
//  MCSHLSResource+MCSPrivate.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSResource.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSHLSResource (MCSPrivate)

@property (nonatomic) NSInteger id;
@property (nonatomic, copy, readonly, nullable) NSString *server;
@property (nonatomic, copy, readonly, nullable) NSString *name;

@end

NS_ASSUME_NONNULL_END
