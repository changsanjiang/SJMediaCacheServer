//
//  MCSLocalProxyServer.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSLocalProxyServer.h"
#import "MCSDataRequest.h"
#import "MCSURLConvertor.h"
#import "MCSLogger.h"
#import <objc/message.h>
#import <CocoaHTTPServer/HTTPServer.h>
#import <CocoaHTTPServer/HTTPConnection.h>
#import <CocoaHTTPServer/HTTPResponse.h>
#import <CocoaHTTPServer/HTTPMessage.h>


@interface HTTPServer (MCSLocalProxyServerExtended)
@property (nonatomic, weak, nullable) MCSLocalProxyServer *mcs_server;
@end

@interface MCSHTTPConnection : HTTPConnection
- (HTTPMessage *)mcs_request;
- (MCSLocalProxyServer *)mcs_server;
@end
 
@interface MCSHTTPResponse : NSObject<HTTPResponse, MCSDataResponseDelegate>
- (instancetype)initWithConnection:(MCSHTTPConnection *)connection;
@property (nonatomic, strong) MCSDataRequest * request;
@property (nonatomic, strong) id<MCSDataResponse> response;
@property (nonatomic, weak) MCSHTTPConnection *connection;
- (void)prepareForReadingData;
@end

#pragma mark -

@interface MCSLocalProxyServer ()
@property (nonatomic, strong) HTTPServer *localServer;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property (nonatomic) BOOL wantsRunning;

- (id<MCSDataResponse>)responseWithRequest:(MCSDataRequest *)request delegate:(id<MCSDataResponseDelegate>)delegate;

@end

@implementation MCSLocalProxyServer
- (instancetype)initWithPort:(UInt16)port {
    self = [super init];
    if ( self ) {
        _port = port;
        
        _localServer = HTTPServer.alloc.init;
        _localServer.mcs_server = self;
        [_localServer setConnectionClass:MCSHTTPConnection.class];
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

- (id<MCSDataResponse>)responseWithRequest:(MCSDataRequest *)request delegate:(id<MCSDataResponseDelegate>)delegate {
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

@implementation HTTPServer (MCSLocalProxyServerExtended)
- (void)setMcs_server:(MCSLocalProxyServer *)mcs_server {
    objc_setAssociatedObject(self, @selector(mcs_server), mcs_server, OBJC_ASSOCIATION_ASSIGN);
}

- (MCSLocalProxyServer *)mcs_server {
    return objc_getAssociatedObject(self, _cmd);
}
@end

@implementation MCSHTTPConnection
- (id)initWithAsyncSocket:(GCDAsyncSocket *)newSocket configuration:(HTTPConfig *)aConfig {
    self = [super initWithAsyncSocket:newSocket configuration:aConfig];
    if ( self ) {
        MCSLog(@"\n%@: <%p>.init;\n", NSStringFromClass(self.class), self);
    }
    return self;
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path {
    MCSHTTPResponse *response = [MCSHTTPResponse.alloc initWithConnection:self];
    
    MCSLog(@"%@: <%p>.response { URI: %@, method: %@, range: %@ };\n", NSStringFromClass(self.class), self, method, path, NSStringFromRange(response.request.range));
    
    [response prepareForReadingData];
    return response;
}

- (HTTPMessage *)mcs_request {
    return request;
}

- (MCSLocalProxyServer *)mcs_server {
    return config.server.mcs_server;
}

- (void)finishResponse {
    [super finishResponse];
    
    MCSLog(@"%@: <%p>.finishResponse;\n", NSStringFromClass(self.class), self);
}

- (void)die {
    [super die];
    MCSLog(@"%@: <%p>.die;\n", NSStringFromClass(self.class), self);
}

- (void)dealloc {
    MCSLog(@"%@: <%p>.dealloc;\n\n", NSStringFromClass(self.class), self);
}
@end

@implementation MCSDataRequest (MCSLocalProxyServerExtended)
- (instancetype)initWithHTTPRequest:(HTTPMessage *)request {
    return [self initWithURL:[MCSURLConvertor.shared URLWithProxyURL:[request url]] headers:[request allHeaderFields]];
}
@end

@implementation MCSHTTPResponse
- (instancetype)initWithConnection:(MCSHTTPConnection *)connection {
    self = [super init];
    if ( self ) {
        _connection = connection;
        
        MCSLocalProxyServer *server = [connection mcs_server];
        _request = [MCSDataRequest.alloc initWithHTTPRequest:[connection mcs_request]];
        _response = [server responseWithRequest:_request delegate:self];
    }
    return self;
}

- (void)prepareForReadingData {
    [_response prepare];
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
}

- (BOOL)delayResponseHeaders {
    return _response != nil ? !_response.isPrepared : YES;
}

- (void)responsePrepareDidFinish:(id<MCSDataResponse>)response {
    [_connection responseHasAvailableData:self];
}

- (void)responseHasAvailableData:(id<MCSDataResponse>)response {
    [_connection responseHasAvailableData:self];
}

- (void)response:(id<MCSDataResponse>)response anErrorOccurred:(NSError *)error {
    [_connection responseDidAbort:self];
}
@end
