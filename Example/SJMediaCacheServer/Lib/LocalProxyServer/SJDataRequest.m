//
//  SJDataRequest.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJDataRequest.h"

@implementation SJDataRequest
@synthesize range = _range;
- (instancetype)initWithURL:(NSURL *)URL headers:(NSDictionary *)headers {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _headers = headers.copy;
        //    {
        //        Accept = "*/*";
        //        "Accept-Encoding" = identity;
        //        "Accept-Language" = "zh-cn";
        //        Connection = "keep-alive";
        //        Host = "localhost:80";
        //        Range = "bytes=0-1";
        //        "User-Agent" = "AppleCoreMedia/1.0.0.17D50 (iPhone; U; CPU OS 13_3_1 like Mac OS X; zh_cn)";
        //        "X-Playback-Session-Id" = "70A343D6-4EA2-4F93-839A-BEA1BBC6BF7E";
        //    }
        //
        // https://tools.ietf.org/html/rfc7233#section-3.1
        //
        NSString *bytes = self.headers[@"Range"];
        NSString *prefix = @"bytes=";
        NSString *rangeString = [bytes substringWithRange:NSMakeRange(prefix.length, bytes.length - prefix.length)];
        NSArray<NSString *> *components = [rangeString componentsSeparatedByString:@"-"];
#warning next .... 其他range的情况
        NSUInteger location = (NSUInteger)[components.firstObject longLongValue];
        NSUInteger length = (NSUInteger)[components.lastObject longLongValue] - location + 1;
        _range = NSMakeRange(location, length);
        
#ifdef DEBUG
        NSLog(@"%d - -[%@ %s]", (int)__LINE__, NSStringFromClass([self class]), sel_getName(_cmd));
#endif
    }
    return self;
}
@end
