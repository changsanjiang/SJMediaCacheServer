//
//  MCSDataRequest.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDataRequest.h"
#import "MCSUtils.h"

@implementation MCSDataRequest
- (instancetype)initWithURL:(NSURL *)URL headers:(NSDictionary *)headers {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _headers = headers.copy;
        _range = MCSGetRequestNSRange(MCSGetRequestContentRange(headers));
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"MCSDataRequest:<%p> { URL: %@, headers: %@\n};", self, _URL, _headers];
}
@end
