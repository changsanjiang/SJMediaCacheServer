//
//  MCSError.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/8.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, MCSErrorCode) {
    MCSResponseUnavailableError    = 100000,
    
    MCSResourceHasBeenRemovedError = 100001,
    
    MCSExceptionError              = 100002,

    // unused
//    MCSOutOfDiskSpaceError        = 100003,
    
    MCSHLSFileParseError           = 100004,
    
    MCSFileNotExistError           = 100005,
    
    MCSUserCancelledError          = 100006,
    
    MCSInvalidRequestError         = 100007,
    
    MCSInvalidResponseError        = 100008,
    
    MCSInvalidParameterError       = 100009,
};

FOUNDATION_EXTERN NSString * const MCSErrorDomain;
FOUNDATION_EXTERN NSString * const MCSErrorUserInfoRequestKey;
FOUNDATION_EXTERN NSString * const MCSErrorUserInfoRequestAllHeaderFieldsKey;
FOUNDATION_EXTERN NSString * const MCSErrorUserInfoResponseKey;
FOUNDATION_EXPORT NSString * const MCSErrorUserInfoExceptionKey;
FOUNDATION_EXTERN NSString * const MCSErrorUserInfoResourceKey;
FOUNDATION_EXTERN NSString * const MCSErrorUserInfoRangeKey;
FOUNDATION_EXTERN NSString * const MCSErrorUserInfoErrorKey;

@interface NSError (MCSExtended)
+ (NSError *)mcs_errorWithCode:(MCSErrorCode)code userInfo:(nullable NSDictionary *)userInfo;
@end
NS_ASSUME_NONNULL_END
