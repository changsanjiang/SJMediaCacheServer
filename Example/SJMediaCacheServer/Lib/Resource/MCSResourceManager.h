//
//  MCSResourceManager.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCSURLConvertor.h"
@class MCSResource, MCSResourcePartialContent;

NS_ASSUME_NONNULL_BEGIN

@interface MCSResourceManager : NSObject
+ (instancetype)shared;

@property (nonatomic, strong, readonly) MCSURLConvertor *convertor;

// default value is 20;
@property (nonatomic) NSUInteger countLimit;

- (MCSResource *)resourceWithURL:(NSURL *)URL;

- (void)update:(MCSResource *)resource;

//- (void)
@end

NS_ASSUME_NONNULL_END
