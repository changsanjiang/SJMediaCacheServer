//
//  MCSConsts.m
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/11/25.
//

#import "MCSConsts.h"
 
NSNotificationName const MCSFileWriteOutOfSpaceErrorNotification = @"MCSFileWriteOutOfSpaceErrorNotification";

NSString *const HLS_EXTENSION_PLAYLIST   = @"m3u8";
NSString *const HLS_EXTENSION_SEGMENT    = @"ts";
NSString *const HLS_EXTENSION_KEY    = @"key";
NSString *const HLS_EXTENSION_SUBTITLES  = @"vtt";

NSInteger const MCS_RESPONSE_CODE_OK = 200;
NSInteger const MCS_RESPONSE_CODE_PARTIAL_CONTENT = 206;
NSInteger const MCS_RESPONSE_CODE_BAD = 400;
 
NSString *const kLength = @"length";
