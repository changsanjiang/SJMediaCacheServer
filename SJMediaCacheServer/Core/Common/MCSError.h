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
    MCSNonsupportContentTypeError  = 100002,
    MCSExceptionError              = 100003,

    // unused
//    MCSOutOfDiskSpaceError        = 100004,
    
    MCSHLSFileParseError           = 100005,
    
    MCSHLSAESKeyWriteFailedError   = 100006,
    
    MCSFileNotExistError           = 100007,
    
    MCSUserCancelledError          = 100008,
    
    MCSInvalidRangeError           = 100009,
    
    MCSInvalidParameterError       = 100010,
};

FOUNDATION_EXTERN NSString * const MCSErrorDomain;
FOUNDATION_EXTERN NSString * const MCSErrorUserInfoURLKey;
FOUNDATION_EXTERN NSString * const MCSErrorUserInfoRequestKey;
FOUNDATION_EXTERN NSString * const MCSErrorUserInfoResponseKey;

FOUNDATION_EXTERN NSString * const MCSErrorUserInfoResourceKey;
FOUNDATION_EXTERN NSString * const MCSErrorUserInfoRangeKey;

@interface NSError (MCSExtended)
+ (NSError *)mcs_responseUnavailable:(NSURL *)URL request:(NSURLRequest *)request response:(NSURLResponse *)response;

+ (NSError *)mcs_nonsupportContentType:(NSURL *)URL request:(NSURLRequest *)request response:(NSURLResponse *)response;

+ (NSError *)mcs_exception:(NSException *)exception;

+ (NSError *)mcs_removedResource:(NSURL *)URL;

+ (NSError *)mcs_HLSFileParseError:(NSURL *)URL;

+ (NSError *)mcs_HLSAESKeyWriteFailedError:(NSURL *)URL;

+ (NSError *)mcs_fileNotExistErrorWithUserInfo:(NSDictionary *)userInfo;

+ (NSError *)mcs_userCancelledError:(NSURL *)URL;

+ (NSError *)mcs_invalidRangeErrorWithRequest:(NSURLRequest *)request;

+ (NSError *)mcs_invalidParameterErrorWithUserInfo:(NSDictionary *)userInfo;
@end
NS_ASSUME_NONNULL_END
