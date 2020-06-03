//
//  SJDataRequest.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SJDataRequest : NSObject
- (instancetype)initWithURL:(NSURL *)URL headers:(NSDictionary *)headers;
@property (nonatomic, copy, readonly, nullable) NSURL *URL;
@property (nonatomic, copy, readonly, nullable) NSDictionary *headers;
@property (nonatomic, readonly) NSRange range;
@end

NS_ASSUME_NONNULL_END
