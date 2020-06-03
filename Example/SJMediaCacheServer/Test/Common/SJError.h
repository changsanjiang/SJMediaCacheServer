//
//  SJError.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SJErrorCode) {
    SJErrorCodeResponseUnavailable  = -192700,
    SJErrorCodeUnsupportContentType = -192701,
    SJErrorCodeNotEnoughDiskSpace   = -192702,
    SJErrorCodeException            = -192703,
};

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSErrorDomain const SJErrorDomain;

@interface SJError : NSObject

+ (NSError *)errorForResponseUnavailable:(NSURL *)URL
                                 request:(NSURLRequest *)request
                                response:(NSURLResponse *)response;

+ (NSError *)errorForUnsupportContentType:(NSURL *)URL
                                  request:(NSURLRequest *)request
                                 response:(NSURLResponse *)response;

+ (NSError *)errorForNotEnoughDiskSpace:(long long)totlaContentLength
                                request:(long long)currentContentLength
                       totalCacheLength:(long long)totalCacheLength
                         maxCacheLength:(long long)maxCacheLength;

+ (NSError *)errorForException:(NSException *)exception;

@end
NS_ASSUME_NONNULL_END
