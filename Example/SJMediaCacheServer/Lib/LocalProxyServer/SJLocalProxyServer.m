//
//  SJLocalProxyServer.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJLocalProxyServer.h"
#import "SJDataRequest.h"
#import "SJURLConvertor.h"
#import <objc/message.h>
#import <CocoaHTTPServer/HTTPServer.h>
#import <CocoaHTTPServer/HTTPConnection.h>
#import <CocoaHTTPServer/HTTPResponse.h>
#import <CocoaHTTPServer/HTTPMessage.h>


@interface HTTPServer (SJLocalProxyServerExtended)
@property (nonatomic, weak, nullable) SJLocalProxyServer *sj_server;
@end

@interface SJHTTPConnection : HTTPConnection
- (HTTPMessage *)sj_request;
- (SJLocalProxyServer *)sj_server;
@end
 
@interface SJHTTPResponse : NSObject<HTTPResponse, SJDataResponseDelegate>
- (instancetype)initWithConnection:(SJHTTPConnection *)connection;
@property (nonatomic, strong) SJDataRequest * request;
@property (nonatomic, strong) id<SJDataResponse> response;
@property (nonatomic, weak) SJHTTPConnection *connection;
@end

#pragma mark -

@interface SJLocalProxyServer ()
@property (nonatomic, strong) HTTPServer *localServer;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property (nonatomic) BOOL wantsRunning;

- (id<SJDataResponse>)responseWithRequest:(SJDataRequest *)request delegate:(id<SJDataResponseDelegate>)delegate;

@end

@implementation SJLocalProxyServer
- (instancetype)initWithPort:(UInt16)port {
    self = [super init];
    if ( self ) {
        _port = port;
        
        _localServer = HTTPServer.alloc.init;
        _localServer.sj_server = self;
        [_localServer setConnectionClass:SJHTTPConnection.class];
        [_localServer setType:@"_http._tcp"];
        [_localServer setPort:port];
        
        _backgroundTask = UIBackgroundTaskInvalid;
        
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(connectionDidDie) name:HTTPConnectionDidDieNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (BOOL)isRunning {
    return _localServer.isRunning;
}

- (BOOL)start:(NSError *__autoreleasing  _Nullable *)error {
    _wantsRunning = YES;
    return [self _start:error];
}

- (void)stop {
    _wantsRunning = NO;
    [self _stop];
}

- (id<SJDataResponse>)responseWithRequest:(SJDataRequest *)request delegate:(id<SJDataResponseDelegate>)delegate {
    return [self.delegate server:self responseWithRequest:request delegate:delegate];
}

#pragma mark -

- (void)applicationDidEnterBackground {
    self.localServer.numberOfHTTPConnections > 0 ? [self _beginBackgroundTask]: [self _stop];
}

- (void)applicationWillEnterForeground {
    if ( self.backgroundTask == UIBackgroundTaskInvalid && self.wantsRunning ) {
        [self _start:nil];
    }
    [self _endBackgroundTask];
}

- (void)connectionDidDie {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ( UIApplication.sharedApplication.applicationState == UIApplicationStateBackground && self.localServer.numberOfHTTPConnections == 0 ) {
            [self _endBackgroundTask];
            [self _stop];
        }
    });
}

#pragma mark -

- (BOOL)_start:(NSError **)error {
    return [_localServer start:error];
}

- (void)_stop {
    [_localServer stop];
}

- (void)_beginBackgroundTask {
    if ( self.backgroundTask == UIBackgroundTaskInvalid ) {
        self.backgroundTask = [UIApplication.sharedApplication beginBackgroundTaskWithExpirationHandler:^{
            [self _endBackgroundTask];
            [self _stop];
        }];
    }
}

- (void)_endBackgroundTask {
    if ( self.backgroundTask != UIBackgroundTaskInvalid ) {
        [UIApplication.sharedApplication endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }
}
@end

#pragma mark -

@implementation HTTPServer (SJLocalProxyServerExtended)
- (void)setSj_server:(SJLocalProxyServer *)sj_server {
    objc_setAssociatedObject(self, @selector(sj_server), sj_server, OBJC_ASSOCIATION_ASSIGN);
}

- (SJLocalProxyServer *)sj_server {
    return objc_getAssociatedObject(self, _cmd);
}
@end

@implementation SJHTTPConnection
- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path {
    return [SJHTTPResponse.alloc initWithConnection:self];
}

- (HTTPMessage *)sj_request {
    return request;
}

- (SJLocalProxyServer *)sj_server {
    return config.server.sj_server;
}
@end

@implementation SJDataRequest (SJLocalProxyServerExtended)
- (instancetype)initWithHTTPRequest:(HTTPMessage *)request {
    return [self initWithURL:[SJURLConvertor.shared URLWithProxyURL:[request url]] headers:[request allHeaderFields]];
}
@end

@implementation SJHTTPResponse
- (instancetype)initWithConnection:(SJHTTPConnection *)connection {
    self = [super init];
    if ( self ) {
        _connection = connection;
        
        SJLocalProxyServer *server = [connection sj_server];
        _request = [SJDataRequest.alloc initWithHTTPRequest:[connection sj_request]];
        _response = [server responseWithRequest:_request delegate:self];
        [_response prepare];
    }
    return self;
}

- (UInt64)contentLength {
    return (UInt64)_response.contentLength;
}

- (UInt64)offset {
    return (UInt64)_response.offset;
}

- (void)setOffset:(UInt64)offset { }

- (NSData *)readDataOfLength:(NSUInteger)length {
    return [_response readDataOfLength:length];
}

- (BOOL)isDone {
    return _response.isDone;
}

- (void)connectionDidClose {
    [_response close];
}

- (NSDictionary *)httpHeaders {
    return _response.responseHeaders;
//    NSMutableDictionary *headers = [self.response.responseHeaders mutableCopy];
//    [headers removeObjectForKey:@"Content-Range"];
//    [headers removeObjectForKey:@"content-range"];
//    [headers removeObjectForKey:@"Content-Length"];
//    [headers removeObjectForKey:@"content-length"];
//    return headers;
}

- (BOOL)delayResponseHeaders {
    return _response != nil ? !_response.isPrepared : YES;
}

- (void)responsePrepareDidFinish:(id<SJDataResponse>)response {
    [_connection responseHasAvailableData:self];
}

- (void)responseHasAvailableData:(id<SJDataResponse>)response {
    [_connection responseHasAvailableData:self];
}

- (void)response:(id<SJDataResponse>)response anErrorOccurred:(NSError *)error {
    [_connection responseDidAbort:self];
}
@end
