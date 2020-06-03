//
//  SJLocalProxyServer.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJMediaCacheServerDefines.h"
@protocol SJLocalProxyServerDelegate;

NS_ASSUME_NONNULL_BEGIN
@interface SJLocalProxyServer : NSObject
- (instancetype)initWithPort:(UInt16)port;
@property (nonatomic, weak, nullable) id<SJLocalProxyServerDelegate> delegate;

@property (nonatomic, readonly) UInt16 port;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
- (BOOL)start:(NSError **)error;
- (void)stop;
@end

@protocol SJLocalProxyServerDelegate <NSObject>
- (id<SJDataResponse>)server:(SJLocalProxyServer *)server responseWithRequest:(SJDataRequest *)request delegate:(id<SJDataResponseDelegate>)delegate;
@end
NS_ASSUME_NONNULL_END
