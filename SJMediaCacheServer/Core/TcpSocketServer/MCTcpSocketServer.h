//
//  MCTcpSocketServer.h
//  Pods
//
//  Created by db on 2025/3/8.
//

#import <Foundation/Foundation.h>
#import <Network/Network.h>
@class MCTcpSocketConnection;

NS_ASSUME_NONNULL_BEGIN
@interface MCTcpSocketServer : NSObject
@property (nonatomic, copy, nullable) void(^onListen)(uint16_t port);
@property (nonatomic, copy, nullable) void(^onConnect)(MCTcpSocketConnection *connection);
@property (nonatomic, readonly) uint16_t port;
@property (nonatomic, readonly, getter=isRunning) BOOL running;
- (BOOL)start;
- (void)stop;
@end

@interface MCTcpSocketConnection : NSObject
@property (nonatomic, copy, nullable) void(^onStateChange)(MCTcpSocketConnection* connection, nw_connection_state_t state, nw_error_t _Nullable error);
@property (nonatomic, readonly) nw_connection_state_t state;
@property (nonatomic, readonly) dispatch_queue_t queue;

- (void)start;

- (void)receiveDataWithMinimumIncompleteLength:(uint32_t)minimumIncompleteLength
                                 maximumLength:(uint32_t)maximumLength
                                    completion:(nw_connection_receive_completion_t)completion;

- (dispatch_data_t)createData:(NSData *)data;
- (dispatch_data_t)createDataWithString:(NSString *)string;
- (dispatch_data_t)createDataWithString:(NSString *)string encoding:(NSStringEncoding)encoding;

- (void)sendData:(dispatch_data_t)data
         context:(nw_content_context_t)context
      isComplete:(bool)isComplete
      completion:(nw_connection_send_completion_t)completion;

- (void)close;
@end
NS_ASSUME_NONNULL_END
