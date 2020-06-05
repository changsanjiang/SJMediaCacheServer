//
//  SJError.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJError.h"

NSString * const SJErrorUserInfoKeyURL      = @"SJErrorUserInfoKeyURL";
NSString * const SJErrorUserInfoKeyRequest  = @"SJErrorUserInfoKeyRequest";
NSString * const SJErrorUserInfoKeyResponse = @"SJErrorUserInfoKeyResponse";

NSErrorDomain const SJErrorDomain           = @"SJMediaCacheServer error";

@implementation SJError

+ (NSError *)errorForResponseUnavailable:(NSURL *)URL
                                 request:(NSURLRequest *)request
                                response:(NSURLResponse *)response
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (URL) {
        [userInfo setObject:URL forKey:SJErrorUserInfoKeyURL];
    }
    if (request) {
        [userInfo setObject:request forKey:SJErrorUserInfoKeyRequest];
    }
    if (response) {
        [userInfo setObject:response forKey:SJErrorUserInfoKeyResponse];
    }
    NSError *error = [NSError errorWithDomain:SJErrorDomain
                                         code:SJErrorCodeResponseUnavailable
                                     userInfo:userInfo];
    return error;
}

+ (NSError *)errorForNonsupportContentType:(NSURL *)URL
                                   request:(NSURLRequest *)request
                                  response:(NSURLResponse *)response
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (URL) {
        [userInfo setObject:URL forKey:SJErrorUserInfoKeyURL];
    }
    if (request) {
        [userInfo setObject:request forKey:SJErrorUserInfoKeyRequest];
    }
    if (response) {
        [userInfo setObject:response forKey:SJErrorUserInfoKeyResponse];
    }
    NSError *error = [NSError errorWithDomain:SJErrorDomain
                                         code:SJErrorCodeNonsupportContentType
                                     userInfo:userInfo];
    return error;
}

+ (NSError *)errorForNotEnoughDiskSpace:(long long)totlaContentLength
                                request:(long long)currentContentLength
                       totalCacheLength:(long long)totalCacheLength
                         maxCacheLength:(long long)maxCacheLength
{
    NSError *error = [NSError errorWithDomain:SJErrorDomain
                                         code:SJErrorCodeNotEnoughDiskSpace
                                     userInfo:@{@"totlaContentLength" : @(totlaContentLength),
                                                @"currentContentLength" : @(currentContentLength),
                                                @"totalCacheLength" : @(totalCacheLength),
                                                @"maxCacheLength" : @(maxCacheLength)}];
    return error;
}

+ (NSError *)errorForException:(NSException *)exception
{
    NSError *error = [NSError errorWithDomain:SJErrorDomain
                                        code:SJErrorCodeException
                                    userInfo:exception.userInfo];
    return error;
}


@end
