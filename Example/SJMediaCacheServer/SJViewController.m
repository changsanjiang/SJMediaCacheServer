//
//  SJViewController.m
//  SJMediaCacheServer
//
//  Created by changsanjiang@gmail.com on 05/30/2020.
//  Copyright (c) 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJViewController.h"
#import <SJMediaCacheServer/SJMediaCacheServer.h>
#import <SJVideoPlayer/SJVideoPlayer.h>
#import <Masonry/Masonry.h>
#import <Network/Network.h>

#import <SJMediaCacheServer/MCTcpSocketServer.h>

static NSString *const DEMO_URL = @"http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8";



@interface SJViewController ()
@property (nonatomic, strong, nullable) SJVideoPlayer *player;
@property (nonatomic, strong) nw_connection_t connection;


@property (nonatomic, strong) MCTcpSocketServer *socketServer;
@end

@implementation SJViewController
- (BOOL)shouldAutorotate {
    return NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _player = SJVideoPlayer.player;
    _player.pauseWhenAppDidEnterBackground = NO;
    [self.view addSubview:_player.view];
    [_player.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.offset(0);
        make.centerY.offset(0);
        make.height.offset(210);
    }];
    
    SJMediaCacheServer.shared.enabledConsoleLog = YES;
    
    
    _socketServer = [MCTcpSocketServer.alloc init];
    __weak typeof(self) _self = self;
    _socketServer.onListen = ^(uint16_t port) {
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;
        
    };
    _socketServer.onConnect = ^(MCTcpSocketConnection * _Nonnull connection) {
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;
        [connection receiveDataWithMinimumIncompleteLength:1 maximumLength:1024 completion:^(dispatch_data_t  _Nullable content, nw_content_context_t  _Nullable context, bool is_complete, nw_error_t  _Nullable error) {
            NSString *receivedMessage = [NSString.alloc initWithData:(NSData *)content encoding:NSUTF8StringEncoding];
            NSLog(@"收到消息: %@, %p", receivedMessage, connection);
            
            // 发送响应
            dispatch_data_t data = [connection createDataWithString:@"HTTP/1.1 500 Internal Server Error\r\n\r\n"];
            [connection sendData:data context:NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT isComplete:true completion:^(nw_error_t  _Nullable error) {
                [connection close];
            }];
        }];
    };
    [_socketServer start];
}

- (IBAction)play:(id)sender {
#ifdef DEBUG
    NSLog(@"%d : %s", __LINE__, sel_getName(_cmd));
#endif

    
//    NSURL *playbackURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%hu", _server.port]];
//    _player.URLAsset = [SJVideoPlayerURLAsset.alloc initWithURL:playbackURL startPosition:0];
    
//    [self connectToServer];
    [self test];
}

- (void)test {
#ifdef DEBUG
    NSLog(@"%d : %s", __LINE__, sel_getName(_cmd));
#endif

    NSMutableURLRequest *req = [NSMutableURLRequest.alloc initWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%hu/%ld", _socketServer.port, random()]]];
    req.HTTPMethod = @"HEAD";
    NSLog(@"req: %@", req);
    [[NSURLSession.sharedSession dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"response= %@", response);
    }] resume];
}

- (void)connectToServer {
    char port[16];
    sprintf(port, "%hu", _socketServer.port);
    
    nw_endpoint_t endpoint = nw_endpoint_create_host("127.0.0.1", port);
    nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
    
    nw_connection_t connection = nw_connection_create(endpoint, parameters);
    nw_connection_set_state_changed_handler(connection, ^(nw_connection_state_t state, nw_error_t error) {
        if (state == nw_connection_state_ready) {
            NSLog(@"连接成功");
            [self sendData:connection];
        } else if (state == nw_connection_state_failed) {
            NSLog(@"连接失败");
        }
        
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
    });
    nw_connection_set_queue(connection, dispatch_get_global_queue(0, 0));
    nw_connection_start(connection);
    self.connection = connection;
}

- (void)sendData:(nw_connection_t)connection {
    NSData *message = [@"Hello, Server" dataUsingEncoding:NSUTF8StringEncoding];
    
    dispatch_data_t data = dispatch_data_create(message.bytes, message.length, dispatch_get_main_queue(), DISPATCH_DATA_DESTRUCTOR_DEFAULT);
    
    nw_connection_send(connection, data, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, true, ^(nw_error_t error) {
        if (error == NULL) {
            NSLog(@"发送成功");
        } else {
            NSLog(@"发送失败");
        }
    });

    [self receiveData:connection];
}

- (void)receiveData:(nw_connection_t)connection {
    nw_connection_receive(connection, 1, 1024, ^(dispatch_data_t data, nw_content_context_t context, bool isComplete, nw_error_t error) {
        if (data != NULL) {
            NSString*str = [NSString.alloc initWithData:(NSData *)data encoding:NSUTF8StringEncoding];
            NSLog(@"收到消息: %@", str);
        }
    });
}

@end

















@interface TCPServer : NSObject
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, strong) nw_listener_t listener;
@property (nonatomic) uint16_t port;
- (void)startServer;
@end

@implementation TCPServer {
    nw_connection_t mConnection;
    
}

- (instancetype)init {
    if (self = [super init]) {
        _queue = dispatch_queue_create("tcp_server_queue", DISPATCH_QUEUE_SERIAL);
        
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(startServer) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    return self;
}

- (void)startServer {
    // 1. 创建监听器参数
    nw_parameters_t parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION);
    nw_parameters_set_local_only(parameters, true);
    
    if ( _listener ) {
        nw_listener_cancel(_listener);
    }
    
    // 2. 创建监听器
    nw_listener_t listener = _port == 0 ? nw_listener_create(parameters) : nw_listener_create_with_port([[NSString stringWithFormat:@"%hu", _port] cStringUsingEncoding:NSUTF8StringEncoding], parameters);
    
    nw_listener_set_new_connection_limit(listener, NW_LISTENER_INFINITE_CONNECTION_LIMIT);
    
    if (!listener) {
        NSLog(@"创建监听器失败");
        return;
    }

    self.listener = listener;
     
    // 3. 监听状态变化
    __weak typeof(self) _self = self;
    nw_listener_set_state_changed_handler(listener, ^(nw_listener_state_t state, nw_error_t error) {
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;
        switch (state) {
            case nw_listener_state_ready:
                NSLog(@"服务器已启动，监听端口 %d", nw_listener_get_port(listener));
                self->_port = nw_listener_get_port(listener);
                break;
            case nw_listener_state_failed:
                NSLog(@"监听失败");
                break;
            case nw_listener_state_cancelled:
                NSLog(@"监听已取消");
                break;
            default:
                break;
        }
        
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
    });

    // 4. 接受连接
    nw_listener_set_new_connection_handler(listener, ^(nw_connection_t connection) {
        NSLog(@"收到新的客户端连接");
        [self handleClientConnection:connection];
    });

    nw_listener_set_queue(listener, _queue);
    
    // 5. 启动监听
    nw_listener_start(listener);
}

- (void)handleClientConnection:(nw_connection_t)connection {
    nw_endpoint_t endpoint = nw_connection_copy_endpoint(connection);
    uint16_t port = nw_endpoint_get_port(endpoint);
    NSLog(@"客户端连接: %hu", port);


    mConnection = connection;
    nw_connection_set_state_changed_handler(connection, ^(nw_connection_state_t state, nw_error_t error) {
        if (state == nw_connection_state_ready) {
            NSLog(@"客户端连接成功");
            [self receiveData:connection];
        } else if (state == nw_connection_state_failed || state == nw_connection_state_cancelled) {
            NSLog(@"客户端连接断开: %@", error);
        }
        
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
    });
    nw_connection_set_queue(connection, _queue);
    nw_connection_start(connection);
}

- (void)receiveData:(nw_connection_t)connection {
    nw_connection_receive(connection, 1, 1024, ^(dispatch_data_t data, nw_content_context_t context, bool isComplete, nw_error_t error) {
        if (data) {
//            size_t size = dispatch_data_get_size(data);
//            uint8_t buffer[size + 1];
//            // dispatch_data_copy_bytes(data, 0, size, buffer);
//            buffer[size] = 0;
//            NSLog(@"收到客户端消息: %s", buffer);
            
            
            NSString*message1 = [NSString.alloc initWithData:(NSData *)data encoding:NSUTF8StringEncoding];
            NSLog(@"收到消息: %@, %p", message1, connection);
            
            // 发送响应
//            NSData *message = [@"HTTP/1.1 500 Internal Server Error\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
            NSData *message = [@"HTTP/1.1 500 Internal Server Error\r\nContent-Length: 0\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding];
            [self sendData:connection message:message];
        }
    });
}

- (void)sendData:(nw_connection_t)connection message:(NSData *)message {
    dispatch_data_t data = dispatch_data_create(message.bytes, message.length, self.queue, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
    nw_connection_send(connection, data, NW_CONNECTION_FINAL_MESSAGE_CONTEXT, true, ^(nw_error_t error) {
        if (error == NULL) {
            NSLog(@"发送成功");
        } else {
            NSLog(@"发送失败");
        }
//        nw_connection_cancel(connection);
    });
}

- (void)stopServer {
    if (self.listener) {
        nw_listener_cancel(self.listener);
        self.listener = NULL;
    }
}
@end
