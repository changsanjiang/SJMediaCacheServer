//
//  SJDataRequest.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJDataRequest.h"
#import "SJUtils.h"

@implementation SJDataRequest
- (instancetype)initWithURL:(NSURL *)URL headers:(NSDictionary *)headers {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _headers = headers.copy;
        _range = SJGetRequestNSRange(SJGetRequestContentRange(headers));
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"SJDataRequest:<%p> { URL: %@, headers: %@\n};", self, _URL, _headers];
}
@end
