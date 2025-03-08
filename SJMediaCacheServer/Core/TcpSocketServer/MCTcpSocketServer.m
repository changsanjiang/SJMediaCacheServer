//
//  MCTcpSocketServer.m
//  Pods
//
//  Created by db on 2025/3/8.
//

#import "MCTcpSocketServer.h"
#import <stdatomic.h>

@interface MCTcpSocketConnection () {
    nw_connection_t mConnection;
    dispatch_queue_t mQueue;
}
- (instancetype)initWithConnection:(nw_connection_t)connection queue:(dispatch_queue_t)queue;
@end

@implementation MCTcpSocketConnection

- (instancetype)initWithConnection:(nw_connection_t)connection queue:(dispatch_queue_t)queue {
    self = [super init];
    mConnection = connection;
    mQueue = queue;
    
    __weak typeof(self) _self = self;
    nw_connection_set_state_changed_handler(connection, ^(nw_connection_state_t state, nw_error_t  _Nullable error) {
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;
#ifdef DEBUG
        switch (state) {
            case nw_connection_state_invalid:
                NSLog(@"nw_connection_state_invalid");
                break;
            case nw_connection_state_waiting:
                NSLog(@"nw_connection_state_waiting");
                break;
            case nw_connection_state_preparing:
                NSLog(@"nw_connection_state_preparing");
                break;
            case nw_connection_state_ready:
                NSLog(@"nw_connection_state_ready");
                break;
            case nw_connection_state_failed:
                NSLog(@"nw_connection_state_failed");
                break;
            case nw_connection_state_cancelled:
                NSLog(@"nw_connection_state_cancelled");
                break;
        }
#endif
        
        if ( self->_onStateChange ) self->_onStateChange(self, state, error);
    });
    nw_connection_set_queue(connection, queue);
    return self;
}

- (dispatch_queue_t)queue {
    return mQueue;
}

- (void)dealloc {
    nw_connection_cancel(mConnection);
}

- (void)receiveDataWithMinimumIncompleteLength:(uint32_t)minimumIncompleteLength
                                 maximumLength:(uint32_t)maximumLength
                                    completion:(nw_connection_receive_completion_t)completion {
    nw_connection_receive(mConnection, minimumIncompleteLength, maximumLength, completion);
}

- (void)sendData:(dispatch_data_t)data
         context:(nw_content_context_t)context
      isComplete:(_Bool)isComplete
      completion:(nw_connection_send_completion_t)completion {
    nw_connection_send(mConnection, data, context, isComplete, completion);
}

- (void)close {
    nw_connection_cancel(mConnection);
}
@end



#pragma mark - mark

@interface MCTcpSocketServer () {
    atomic_uint_fast16_t mPort;
    atomic_bool mRunning;
    dispatch_queue_t mServerQueue;
    dispatch_queue_t mConnectionQueue;
    nw_listener_t mListener;
}
@end

@implementation MCTcpSocketServer
- (instancetype)init {
    self = [super init];
    mPort = ATOMIC_VAR_INIT(0);
    mRunning = ATOMIC_VAR_INIT(NO);
    mServerQueue = dispatch_queue_create("lib.sj.MCTcpSocketServer", DISPATCH_QUEUE_SERIAL);
    mConnectionQueue = dispatch_queue_create("lib.sj.MCTcpSocketConnection", DISPATCH_QUEUE_SERIAL);
    return self;
}

- (uint16_t)port {
    return atomic_load_explicit(&mPort, memory_order_relaxed);
}

- (BOOL)isRunning {
    return atomic_load_explicit(&mRunning, memory_order_relaxed);
}

- (void)start {
    @synchronized (self) {
        if ( self.isRunning ) {
            return;
        }
        
        atomic_store(&mRunning, YES);
        [self _restartServer];
    }
}

- (void)stop {
    @synchronized (self) {
        if ( !self.isRunning ) {
            return;
        }
        
        atomic_store(&mRunning, NO);
        
        if ( mListener ) {
            nw_listener_cancel(mListener);
            mListener = NULL;
        }
    }
}

- (void)_restartServer {
    @synchronized (self) {
        if ( mListener ) {
            nw_listener_cancel(mListener);
        }
        
        nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
        nw_parameters_set_local_only(parameters, true);
        
        uint16_t port = self.port;
        if ( port == 0 ) {
            mListener = nw_listener_create(parameters);
        }
        else {
            char port_str[6];
            sprintf(port_str, "%hu", port);
            mListener = nw_listener_create_with_port(port_str, parameters);
        }
        nw_listener_set_new_connection_limit(mListener, NW_LISTENER_INFINITE_CONNECTION_LIMIT);
        nw_listener_set_queue(mListener, mServerQueue);
        __weak typeof(self) _self = self;
        nw_listener_set_state_changed_handler(mListener, ^(nw_listener_state_t state, nw_error_t  _Nullable error) {
            __strong typeof(_self) self = _self;
            if ( self == nil ) return;
#ifdef DEBUG
            switch (state) {
                case nw_listener_state_invalid:
                    NSLog(@"nw_listener_state_invalid");
                    break;
                case nw_listener_state_waiting:
                    NSLog(@"nw_listener_state_waiting");
                    break;
                case nw_listener_state_ready:
                    NSLog(@"nw_listener_state_ready");
                    break;
                case nw_listener_state_failed:
                    NSLog(@"nw_listener_state_failed");
                    break;
                case nw_listener_state_cancelled:
                    NSLog(@"nw_listener_state_cancelled");
                    break;
            }
#endif
            
            @synchronized (self) {
                switch (state) {
                    case nw_listener_state_ready: {
                        if ( self.port == 0 ) {
                            uint16_t port = nw_listener_get_port(self->mListener);
                            atomic_store(&self->mPort, port);
                            if ( self->_onListen ) self->_onListen(port);
                        }
                    }
                        break;
                    case nw_listener_state_waiting:
                        break;
                    case nw_listener_state_invalid:
                    case nw_listener_state_failed:
                    case nw_listener_state_cancelled: {
                        [self _setNeedsRestartServer];
                    }
                        break;
                }
            }
        });
        nw_listener_set_new_connection_handler(mListener, ^(nw_connection_t  _Nonnull connection) {
            __strong typeof(_self) self = _self;
            if ( self == nil ) return;
            if ( !self->_onConnect ) {
                nw_connection_cancel(connection);
                return;
            }
            
            MCTcpSocketConnection *wrapper = [MCTcpSocketConnection.alloc initWithConnection:connection queue:self->mConnectionQueue];
            self->_onConnect(wrapper);
        });
        nw_listener_start(mListener);
    }
}

- (void)_setNeedsRestartServer {
    
}
@end
