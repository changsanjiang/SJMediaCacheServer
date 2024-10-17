//
//  MCSRequest.m
//  SJMediaCacheServer
//
//  Created by db on 2024/10/17.
//

#import "MCSRequest.h"
#import "MCSURL.h"
#import "NSURLRequest+MCS.h"

@implementation MCSRequest
- (instancetype)initWithProxyRequest:(NSURLRequest *)proxyRequest {
    self = [super init];
    _proxyRequest = proxyRequest;    
    return self;
}

- (NSURL *)originalURL {
    return [MCSURL.shared URLWithProxyURL:_proxyRequest.URL];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { originalURL: %@, proxyRequest: %@ };", NSStringFromClass(self.class), self, self.originalURL, _proxyRequest];
}

- (NSURLRequest *)restoreOriginalURLRequest {
    return [_proxyRequest mcs_requestWithRedirectURL:self.originalURL];
}
@end
