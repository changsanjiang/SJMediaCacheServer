//
//  MCSProxyServer.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSInterfaces.h"
@protocol MCSProxyServerDelegate;

NS_ASSUME_NONNULL_BEGIN
@interface MCSProxyServer : NSObject
@property (nonatomic, weak, nullable) id<MCSProxyServerDelegate> delegate;

@property (readonly, getter=isRunning) BOOL running;
@property (strong, readonly) NSURL *serverURL;

- (BOOL)start;
- (void)stop;

@property (nonatomic, copy, nullable) void (^taskAbortCallback)(NSURLRequest *request, NSError *_Nullable error);
@end

@protocol MCSProxyServerDelegate <NSObject>
- (id<MCSProxyTask>)server:(MCSProxyServer *)server taskWithRequest:(NSURLRequest *)request delegate:(id<MCSProxyTaskDelegate>)delegate;
- (void)serverDidStart:(MCSProxyServer *)server;
@end
NS_ASSUME_NONNULL_END
