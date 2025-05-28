//
//  MCTcpSocketServer.m
//  Pods
//
//  Created by db on 2025/3/8.
//

#import "MCTcpSocketServer.h"
#import <stdatomic.h>
#import "MCPin.h"
#import "MCSRootDirectory.h"
#import "NSFileHandle+MCS.h"
#import "NSFileManager+MCS.h"

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
#ifdef SJDEBUG1
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
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;

        if ( self->_onStateChange ) self->_onStateChange(self, state, error);
    });
    nw_connection_set_queue(connection, queue);
    return self;
}

#ifdef SJDEBUG
- (void)dealloc {
    NSLog(@"%@<%p>: %d : %s", NSStringFromClass(self.class), self, __LINE__, sel_getName(_cmd));
}
#endif

- (dispatch_queue_t)queue {
    return mQueue;
}

- (void)start {
    nw_connection_start(mConnection);
}

- (void)receiveDataWithMinimumIncompleteLength:(uint32_t)minimumIncompleteLength
                                 maximumLength:(uint32_t)maximumLength
                                    completion:(nw_connection_receive_completion_t)completion {
    nw_connection_receive(mConnection, minimumIncompleteLength, maximumLength, completion);
}

- (dispatch_data_t)createData:(NSData *)data {
    return dispatch_data_create(data.bytes, data.length, mQueue, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
}
- (dispatch_data_t)createDataWithString:(NSString *)string {
    return [self createDataWithString:string encoding:NSUTF8StringEncoding];
}
- (dispatch_data_t)createDataWithString:(NSString *)string encoding:(NSStringEncoding)encoding {
    return [self createData:[string dataUsingEncoding:encoding]];
}

- (void)sendData:(nullable dispatch_data_t)data
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
    MCPin *mPin;
    BOOL mShouldRestartServer;
}
@end

@implementation MCTcpSocketServer
#ifdef DEBUG
static NSString *MCErrorLogsFilePath;
+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        MCErrorLogsFilePath = [MCSRootDirectory.path stringByAppendingPathComponent:@"err_logs.txt"];
        if ( ![NSFileManager.defaultManager fileExistsAtPath:MCErrorLogsFilePath] ) {
            [NSFileManager.defaultManager createFileAtPath:MCErrorLogsFilePath contents:nil attributes:nil];
        }
    });
}
#endif

- (instancetype)init {
    self = [super init];
    mPort = ATOMIC_VAR_INIT(0);
    mRunning = ATOMIC_VAR_INIT(NO);
    mServerQueue = dispatch_queue_create("lib.sj.MCTcpSocketServer", DISPATCH_QUEUE_SERIAL);
    mConnectionQueue = dispatch_queue_create("lib.sj.MCTcpSocketConnection", DISPATCH_QUEUE_SERIAL);
    __weak typeof(self) _self = self;
    mPin = [MCPin.alloc initWithInterval:2 failureHandler:^{
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;
        @synchronized (self) {
            if ( self.isRunning ) {
#ifdef DEBUG
                [self _logMsg:[NSString stringWithFormat:@"Pin failed! Listener: %@, Port: %u", self->mListener, self.port]];
#endif
                if ( self->mListener ) {
                    nw_listener_cancel(self->mListener);
                    self->mListener = nil;
                }
                [self _setNeedsRestartServer];
            }
        }
    }];
    
#ifdef DEBUG
    [self _logMsg:@"Init;"];
#endif
    return self;
}

- (void)dealloc {
    [self stop];
}

- (uint16_t)port {
    return atomic_load_explicit(&mPort, memory_order_relaxed);
}

- (BOOL)isRunning {
    return atomic_load_explicit(&mRunning, memory_order_relaxed);
}

- (BOOL)start {
    @synchronized (self) {
        if ( self.isRunning ) {
            return YES;
        }
        
        [self _startServer];
        
        if ( self.port == 0 ) {
            return NO;
        }
        
        atomic_store(&mRunning, YES);
        return YES;
    }
}

- (void)stop {
    @synchronized (self) {
        if ( !self.isRunning ) {
            return;
        }
        
        atomic_store(&mRunning, NO);
        
        if ( mPin ) {
            [mPin stop];
            mPin = nil;
        }
        
        if ( mListener ) {
            nw_listener_set_new_connection_handler(mListener, nil);
            nw_listener_set_state_changed_handler(mListener, nil);
            nw_listener_cancel(mListener);
            mListener = NULL;
        }
    }
}

- (void)_startServer {
    [self _startServerWithPort:0];
}

- (void)_startServerWithPort:(uint16_t)port {
#ifdef DEBUG
    [self _logMsg:[NSString stringWithFormat:@"Start Server with Port: %u;", port]];
#endif
    
    dispatch_semaphore_t sync = dispatch_semaphore_create(0);
    __block dispatch_semaphore_t syncPtr = sync;
    char port_str[6];
    sprintf(port_str, "%hu", port);

    nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
    nw_endpoint_t endpoint = nw_endpoint_create_host("127.0.0.1", port_str);
    nw_parameters_set_local_endpoint(parameters, endpoint);
    nw_listener_t listener = nw_listener_create(parameters);
    nw_listener_set_queue(listener, mServerQueue);
    __weak typeof(self) _self = self;
    nw_listener_set_state_changed_handler(listener, ^(nw_listener_state_t state, nw_error_t  _Nullable error) {
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;
        
#ifdef DEBUG
        [self _logMsg:[NSString stringWithFormat:@"Server state change: %@, %u, %d;", listener, port, state]];
        
        if ( error ) {
            [self _logError:error];
        }
#endif
        
#ifdef SJDEBUG
        switch (state) {
            case nw_listener_state_invalid:
                NSLog(@"nw_listener_state_invalid: %p", listener);
                break;
            case nw_listener_state_waiting:
                NSLog(@"nw_listener_state_waiting: %p", listener);
                break;
            case nw_listener_state_ready:
                NSLog(@"nw_listener_state_ready: %p", listener);
                break;
            case nw_listener_state_failed:
                NSLog(@"nw_listener_state_failed: %p", listener);
                break;
            case nw_listener_state_cancelled:
                NSLog(@"nw_listener_state_cancelled: %p", listener);
                break;
        }
#endif
        // 如果端口号被占用了, 将当前端口号置0重新分配;
        if ( error ) {
            nw_error_domain_t err_domain = nw_error_get_error_domain(error);
            if ( err_domain == nw_error_domain_posix ) {
                int err_code = nw_error_get_error_code(error);
                if ( err_code == EADDRINUSE ) {
                    atomic_store(&self->mPort, 0);
                }
            }
        }
        
        // 设置端口号
        // 启动 pin
        if ( state == nw_listener_state_ready ) {
            uint16_t p = nw_listener_get_port(listener);
            if ( p != self.port ) {
                atomic_store(&self->mPort, p);
                if ( self->_onListen ) self->_onListen(p);
            }
            [self->mPin startWithPort:p];
        }
        
        // 释放同步锁
        if ( syncPtr ) {
            switch (state) {
                case nw_listener_state_invalid:
                case nw_listener_state_waiting:
                    break;
                case nw_listener_state_ready:
                case nw_listener_state_failed:
                case nw_listener_state_cancelled: {
                    dispatch_semaphore_signal(syncPtr);
                    syncPtr = nil;
                }
                    break;
            }
        }
        
        // 报错时重启
        if ( state == nw_listener_state_failed ) {
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                @synchronized (self) {
                    if ( self.isRunning && self->mListener == listener ) {
                        if ( self->mListener ) {
                            nw_listener_cancel(self->mListener);
                            self->mListener = nil;
                        }
                        [self _setNeedsRestartServer];
                    }
                }
            });
        }
    });
    nw_listener_set_new_connection_handler(listener, ^(nw_connection_t  _Nonnull connection) {
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;
        @synchronized (self) {
            [self _onConnect:connection];
        }
    });
    mListener = listener;
    nw_listener_start(listener);
    dispatch_semaphore_wait(sync, DISPATCH_TIME_FOREVER);
}

- (void)_onConnect:(nw_connection_t)connection {
    if ( !_onConnect ) {
        nw_connection_cancel(connection);
        return;
    }
    
    MCTcpSocketConnection *wrapper = [MCTcpSocketConnection.alloc initWithConnection:connection queue:self->mConnectionQueue];
    _onConnect(wrapper);
}

- (void)_setNeedsRestartServer {
#ifdef DEBUG
    [self _logMsg:[NSString stringWithFormat:@"SetNeedsRestartServer; ShouldRestartServer: %d;", mShouldRestartServer]];
#endif
    
    if ( !mShouldRestartServer ) {
        mShouldRestartServer = YES;
        __weak typeof(self) _self = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
            __strong typeof(_self) self = _self;
            if ( self == nil ) return;
            @synchronized (self) {
                if ( self.isRunning && self->mShouldRestartServer ) {
                    [self _restartServer];
                }
            }
        });
    }
}

- (void)_restartServer {
#ifdef DEBUG
    [self _logMsg:[NSString stringWithFormat:@"Restart Server; Listener: %@, Port: %u;", mListener, self.port]];
#endif
    
    if ( mListener ) {
        nw_listener_cancel(mListener);
        mListener = nil;
    }
    
    mShouldRestartServer = NO;
    [self _startServerWithPort:self.port];
}

#ifdef DEBUG
- (void)_logMsg:(NSString *)msg {
    [self _logMsg:msg level:@"I"];
}

- (void)_logError:(nw_error_t)error {
    NSString *log = [NSString stringWithFormat:@"Port: %d, Domain: %d, Code: %d, Desc: %@", self.port, nw_error_get_error_domain(error), nw_error_get_error_code(error), error];
    [self _logMsg:log level:@"E"];
}

- (void)_logMsg:(NSString *)msg level:(NSString *)level {
    NSDate *date = NSDate.new;
    NSDateFormatter *formatter = [NSDateFormatter.alloc init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    
    NSString *content = [NSString stringWithFormat:@"%@ %@: %@\n", [formatter stringFromDate:date], level, msg];
    NSFileHandle *fileHandle = [NSFileHandle mcs_fileHandleForWritingToURL:[NSURL fileURLWithPath:MCErrorLogsFilePath] error:NULL];
    [fileHandle seekToEndOfFile];
    [fileHandle writeData:[content dataUsingEncoding:NSUTF8StringEncoding]];
    [fileHandle closeFile];
}
#endif
@end
