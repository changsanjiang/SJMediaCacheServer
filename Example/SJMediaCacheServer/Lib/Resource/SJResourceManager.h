//
//  SJResourceManager.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SJURLConvertor.h"
@class SJResource, SJResourcePartialContent;

NS_ASSUME_NONNULL_BEGIN

@interface SJResourceManager : NSObject
+ (instancetype)shared;

@property (nonatomic, strong, readonly) SJURLConvertor *convertor;

- (SJResource *)resourceWithURL:(NSURL *)URL;

- (void)update:(SJResource *)resource;
@end

NS_ASSUME_NONNULL_END
