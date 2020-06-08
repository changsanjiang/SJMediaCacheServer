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
    MCSErrorRemoved               = 100003,

    // unused
//    MCSErrorOutOfDiskSpace        = 100004,
};

FOUNDATION_EXTERN NSString * const MCSErrorDomain;
FOUNDATION_EXTERN NSString * const MCSErrorUserInfoURLKey;
FOUNDATION_EXTERN NSString * const MCSErrorUserInfoRequestKey;
FOUNDATION_EXTERN NSString * const MCSErrorUserInfoResponseKey;


@interface NSError (MCSExtended)
+ (NSError *)mcs_errorForResponseUnavailable:(NSURL *)URL request:(NSURLRequest *)request response:(NSURLResponse *)response;

+ (NSError *)mcs_errorForNonsupportContentType:(NSURL *)URL request:(NSURLRequest *)request response:(NSURLResponse *)response;

+ (NSError *)mcs_errorForException:(NSException *)exception;

+ (NSError *)mcs_errorForResourceRemoved:(NSURL *)URL;
@end
NS_ASSUME_NONNULL_END
