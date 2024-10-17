//
//  MCSRequest.h
//  SJMediaCacheServer
//
//  Created by db on 2024/10/17.
//

#import "MCSInterfaces.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSRequest : NSObject<MCSRequest>
- (instancetype)initWithProxyRequest:(NSURLRequest *)proxyRequest;

@property (nonatomic, strong, readonly) NSURLRequest *proxyRequest;

- (NSURLRequest *)restoreOriginalURLRequest;
@end


@interface MCSRequest (Extensions)
@property (nonatomic, strong, readonly) NSURL *originalURL;
@end
NS_ASSUME_NONNULL_END
