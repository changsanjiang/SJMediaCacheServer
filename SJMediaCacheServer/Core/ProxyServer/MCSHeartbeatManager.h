//
//  MCSHeartbeatManager.h
//  SJMediaCacheServer
//
//  Created by db on 2024/10/11.
//

#import <Foundation/Foundation.h>
@class HTTPMessage;

NS_ASSUME_NONNULL_BEGIN

@interface MCSHeartbeatManager : NSObject
- (instancetype)initWithInterval:(NSTimeInterval)heartbeatInterval failureHandler:(void(^)(MCSHeartbeatManager *mgr))block;

@property (nonatomic) NSTimeInterval heartbeatInterval; // 默认5s; 发送心跳包的间隔;
@property (nonatomic) NSTimeInterval timeoutInterval; // 默认2s; 心跳包超时时间;
@property (nonatomic) NSInteger maxAttempts; // 默认3次; 重试次数;

@property (atomic, strong, nullable) NSURL *serverURL;

- (void)startHeartbeat; // 开始发送心跳包
- (void)stopHeartbeat;  // 停止发送心跳包

- (BOOL)isHeartBeatRequest:(HTTPMessage *)msg;
@end

NS_ASSUME_NONNULL_END
