//
//  SJResourceResponse.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/4.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceResponse.h"

@implementation SJResourceResponse
 - (instancetype)initWithRange:(NSRange)range allHeaderFields:(NSDictionary *)allHeaderFields {
    self = [super init];
    if ( self ) {
        _contentRange = range;
        NSMutableDictionary *headers = allHeaderFields.mutableCopy;
        [headers removeObjectForKey:@"Content-Range"];
        [headers removeObjectForKey:@"content-range"];
        [headers removeObjectForKey:@"Content-Length"];
        [headers removeObjectForKey:@"content-length"];
        _responseHeaders = headers;
    }
    return self;
}

- (NSUInteger)contentLength {
    return _contentRange.length;
}
@end
