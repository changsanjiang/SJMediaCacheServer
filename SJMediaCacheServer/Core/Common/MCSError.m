//
//  MCSError.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/8.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSError.h"

NSString * const MCSErrorDomain = @"lib.changsanjiang.SJMediaCacheServer.error";
NSString * const MCSErrorUserInfoURLKey = @"URL";

NSString * const MCSErrorUserInfoRequestKey = @"Request";
NSString * const MCSErrorUserInfoRequestAllHeaderFieldsKey = @"RequestAllHeaderFields";
NSString * const MCSErrorUserInfoExceptionKey = @"Exception";
NSString * const MCSErrorUserInfoResponseKey = @"Response";
NSString * const MCSErrorUserInfoResourceKey = @"Resource";
NSString * const MCSErrorUserInfoRangeKey = @"Range";
NSString * const MCSErrorUserInfoErrorKey = @"Error";

@implementation NSError(MCSExtended)
+ (NSError *)mcs_errorWithCode:(MCSErrorCode)code userInfo:(nullable NSDictionary *)userInfo {
    return [NSError errorWithDomain:MCSErrorDomain code:code userInfo:userInfo];
}
@end
