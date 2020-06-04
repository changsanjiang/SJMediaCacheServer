//
//  SJResourceResponse.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/4.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceResponse.h"

@implementation SJResourceResponse
- (instancetype)initWithResponse:(NSHTTPURLResponse *)response {
    NSDictionary *responseHeaders = response.allHeaderFields;
    NSString *bytes = responseHeaders[@"Content-Range"];
    NSString *prefix = @"bytes ";
    NSString *rangeString = [bytes substringWithRange:NSMakeRange(prefix.length, bytes.length - prefix.length)];
    NSArray<NSString *> *components = [rangeString componentsSeparatedByString:@"-"];
    NSUInteger location = (NSUInteger)[components.firstObject longLongValue];
    NSUInteger length = (NSUInteger)[components.lastObject longLongValue] - location + 1;
    NSUInteger totalLength = (NSUInteger)[components.lastObject.lastPathComponent longLongValue];
    return [self initWithServer:responseHeaders[@"Server"] contentType:responseHeaders[@"Content-Type"] totalLength:totalLength contentRange:NSMakeRange(location, length)];
}

- (instancetype)initWithServer:(NSString *)server contentType:(NSString *)contentType totalLength:(NSUInteger)totalLength contentRange:(NSRange)contentRange {
    self = [super init];
    if ( self ) {
        _responseHeaders = @{
            @"Server" : server ?: @"localhost",
            @"Content-Type" : contentType ?: @"",
            @"Accept-Ranges" : @"bytes",
        };

//            @"Content-Length" : @(totalLength),
//            @"Content-Range" : [NSString stringWithFormat:@"bytes %lu-%lu/%lu", (unsigned long)_contentRange.location, (unsigned long)_contentRange.length - 1, (unsigned long)totalLength],

        _contentType = contentType;
        _totalLength = totalLength;
        _contentRange = contentRange;
        
//  https://tools.ietf.org/html/rfc7233#section-4.1
//
//        2.3.  Accept-Ranges
//
//        The "Accept-Ranges" header field allows a server to indicate that it
//        supports range requests for the target resource.
//
//          Accept-Ranges     = acceptable-ranges
//          acceptable-ranges = 1#range-unit / "none"
//
//        An origin server that supports byte-range requests for a given target
//        resource MAY send
//
//          Accept-Ranges: bytes
//
//        to indicate what range units are supported.  A client MAY generate
//        range requests without having received this header field for the
//        resource involved.  Range units are defined in Section 2.
//
//        A server that does not support any kind of range request for the
//        target resource MAY send
//
//          Accept-Ranges: none
//
//        to advise the client not to attempt a range request.
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"SJResourceResponse:<%p> { responseHeaders: %@ };", self, _responseHeaders];
}
@end
