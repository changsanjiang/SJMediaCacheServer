//
//  MCSProxyServer.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDefines.h"
@protocol MCSProxyServerDelegate;

NS_ASSUME_NONNULL_BEGIN
@interface MCSProxyServer : NSObject
- (instancetype)initWithPort:(UInt16)port;
@property (nonatomic, weak, nullable) id<MCSProxyServerDelegate> delegate;

@property (nonatomic, readonly) UInt16 port;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
- (BOOL)start:(NSError **)error;
- (void)stop;
@end

@protocol MCSProxyServerDelegate <NSObject>
- (id<MCSSessionTask>)server:(MCSProxyServer *)server taskWithRequest:(NSURLRequest *)request delegate:(id<MCSSessionTaskDelegate>)delegate;
@end
NS_ASSUME_NONNULL_END
