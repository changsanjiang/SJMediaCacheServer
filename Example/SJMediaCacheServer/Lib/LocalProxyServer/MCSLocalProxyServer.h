//
//  MCSLocalProxyServer.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDefines.h"
@protocol MCSLocalProxyServerDelegate;

NS_ASSUME_NONNULL_BEGIN
@interface MCSLocalProxyServer : NSObject
- (instancetype)initWithPort:(UInt16)port;
@property (nonatomic, weak, nullable) id<MCSLocalProxyServerDelegate> delegate;

@property (nonatomic, readonly) UInt16 port;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
- (BOOL)start:(NSError **)error;
- (void)stop;
@end

@protocol MCSLocalProxyServerDelegate <NSObject>
- (id<MCSDataResponse>)server:(MCSLocalProxyServer *)server responseWithRequest:(MCSDataRequest *)request delegate:(id<MCSDataResponseDelegate>)delegate;
@end
NS_ASSUME_NONNULL_END
