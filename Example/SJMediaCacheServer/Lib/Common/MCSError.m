//
//  MCSError.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/8.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSError.h"

NSString * const MCSErrorDomain = @"lib.changsanjiang.SJMediaServerCache.error";
NSString * const MCSErrorUserInfoURLKey = @"URL";
NSString * const MCSErrorUserInfoRequestKey = @"Request";
NSString * const MCSErrorUserInfoResponseKey = @"Response";

@implementation NSError(MCSExtended)
+ (NSError *)mcs_errorForResponseUnavailable:(NSURL *)URL request:(NSURLRequest *)request response:(NSURLResponse *)response {
    NSMutableDictionary *userInfo = NSMutableDictionary.dictionary;
    userInfo[MCSErrorUserInfoURLKey] = URL;
    userInfo[MCSErrorUserInfoRequestKey] = request;
    userInfo[MCSErrorUserInfoResponseKey] = response;
    return [NSError errorWithDomain:MCSErrorDomain code:MCSErrorResponseUnavailable userInfo:userInfo];
}

+ (NSError *)mcs_errorForNonsupportContentType:(NSURL *)URL request:(NSURLRequest *)request response:(NSURLResponse *)response {
    NSMutableDictionary *userInfo = NSMutableDictionary.dictionary;
    userInfo[MCSErrorUserInfoURLKey] = URL;
    userInfo[MCSErrorUserInfoRequestKey] = request;
    userInfo[MCSErrorUserInfoResponseKey] = response;
    return [NSError errorWithDomain:MCSErrorDomain code:MCSErrorNonsupportContentType userInfo:userInfo];
}

+ (NSError *)mcs_errorForException:(NSException *)exception {
    return [NSError errorWithDomain:MCSErrorDomain code:MCSErrorException userInfo:exception.userInfo];
}
@end
