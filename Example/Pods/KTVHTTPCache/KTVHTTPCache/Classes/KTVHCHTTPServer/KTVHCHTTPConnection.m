//
//  KTVHCHTTPConnection.m
//  KTVHTTPCache
//
//  Created by Single on 2017/8/10.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "KTVHCHTTPConnection.h"
#import "KTVHCHTTPResponse.h"
#import "KTVHCDataStorage.h"
#import "KTVHCURLTool.h"
#import "KTVHCLog.h"

@implementation KTVHCHTTPConnection

- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig
{
    if (self = [super initWithAsyncSocket:newSocket configuration:aConfig]) {
        KTVHCLogAlloc(self);
        
#ifdef DEBUG
        printf("\n%s: <%p>.init;\n", NSStringFromClass(self.class).UTF8String, self);
#endif

    }
    return self;
}
 
- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    KTVHCLogHTTPConnection(@"%p, Receive request\nmethod : %@\npath : %@\nURL : %@", self, method, path, request.url);
    NSDictionary<NSString *,NSString *> *parameters = [[KTVHCURLTool tool] parseQuery:request.url.query];
    NSURL *URL = [NSURL URLWithString:[parameters objectForKey:@"url"]];
    KTVHCDataRequest *dataRequest = [[KTVHCDataRequest alloc] initWithURL:URL headers:request.allHeaderFields];
    
 #ifdef DEBUG
    printf("%s: <%p>.response { range: {%lld, %lld}}, URI: %s, method: %s };\n", NSStringFromClass(self.class).UTF8String, self, dataRequest.range.start, dataRequest.range.end + 1 - dataRequest.range.start, path.UTF8String, method.UTF8String);
 #endif
    
    KTVHCHTTPResponse *response = [[KTVHCHTTPResponse alloc] initWithConnection:self dataRequest:dataRequest];
    return response;
}

- (void)finishResponse {
    [super finishResponse];
#ifdef DEBUG
    printf("%s: <%p>.finishResponse;\n\n", NSStringFromClass(self.class).UTF8String, self);
#endif
}

- (void)die {
    [super die];
#ifdef DEBUG
    printf("%s: <%p>.die;\n", NSStringFromClass(self.class).UTF8String, self);
#endif
}

- (void)dealloc {
#ifdef DEBUG
    printf("%s: <%p>.dealloc;\n\n", NSStringFromClass(self.class).UTF8String, self);
#endif
    
    KTVHCLogDealloc(self);
}
@end
