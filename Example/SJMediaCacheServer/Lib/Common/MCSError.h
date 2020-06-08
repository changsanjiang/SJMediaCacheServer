//
//  MCSError.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/8.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, MCSErrorCode) {
    MCSErrorResponseUnavailable   = 100000,
    MCSErrorNonsupportContentType = 100001,
    MCSErrorException             = 100002,
#warning next ...
    // 暂时保留
    //    MCSNotEnoughDiscSpace = 100003,
};

FOUNDATION_EXPORT NSString * const MCSErrorDomain;
FOUNDATION_EXPORT NSString * const MCSErrorUserInfoURLKey;
FOUNDATION_EXPORT NSString * const MCSErrorUserInfoRequestKey;
FOUNDATION_EXPORT NSString * const MCSErrorUserInfoResponseKey;


@interface NSError (MCSExtended)
+ (NSError *)mcs_errorForResponseUnavailable:(NSURL *)URL request:(NSURLRequest *)request response:(NSURLResponse *)response;

+ (NSError *)mcs_errorForNonsupportContentType:(NSURL *)URL request:(NSURLRequest *)request response:(NSURLResponse *)response;

+ (NSError *)mcs_errorForException:(NSException *)exception;
@end
NS_ASSUME_NONNULL_END
