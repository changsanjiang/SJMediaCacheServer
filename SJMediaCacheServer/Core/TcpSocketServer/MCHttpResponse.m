//
//  MCHttpResponse.m
//  SJMediaCacheServer
//
//  Created by 畅三江 on 2025/3/9.
//

#import "MCHttpResponse.h"
#import "MCSProxyTask.h"
#import "MCTcpSocketServer.h"
#import "MCHttpRequest.h"
#import "MCHttpRequestRange.h"
#import "MCPin.h"

@interface MCHttpResponse ()<MCSProxyTaskDelegate>

@end

@implementation MCHttpResponse {
    MCTcpSocketConnection *mConnection;
    MCSProxyTask *mTask;
    id mStrongSelf;
    BOOL mHeaderHasSent;
    BOOL mSending;
    BOOL mClosed;
}

+ (void)processConnection:(MCTcpSocketConnection *)connection {
    [MCHttpResponse httpResponseWithConnection:connection];
}

+ (instancetype)httpResponseWithConnection:(MCTcpSocketConnection *)connection {
    return [MCHttpResponse.alloc initWithConnection:connection];
}

- (instancetype)initWithConnection:(MCTcpSocketConnection *)connection {
    self = [super init];
    mConnection = connection;
    mStrongSelf = self;
    
    __weak typeof(self) _self = self;
    connection.onStateChange = ^(MCTcpSocketConnection * _Nonnull connection, nw_connection_state_t state, nw_error_t  _Nullable error) {
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;
        [self _connectionStateDidChange:state error:error];
    };
    [connection start];
    return self;
}

#ifdef SJDEBUG
- (void)dealloc {
    NSLog(@"%@<%p>: %d : %s", NSStringFromClass(self.class), self, __LINE__, sel_getName(_cmd));
}
#endif

- (void)_connectionStateDidChange:(nw_connection_state_t)state error:(nw_error_t _Nullable)error {
    if ( mClosed ) {
        return;
    }
    
    switch (state) {
        case nw_connection_state_waiting:
        case nw_connection_state_preparing:
            break;
        case nw_connection_state_ready: {
            [self _receiveData];
        }
            break;
        case nw_connection_state_invalid:
        case nw_connection_state_failed:
        case nw_connection_state_cancelled: {
            [self _close];
        }
            break;
    }
}

- (void)_receiveData {
    __weak typeof(self) _self = self;
    [mConnection receiveDataWithMinimumIncompleteLength:1 maximumLength:4 * 1024 * 1024 completion:^(dispatch_data_t  _Nullable content, nw_content_context_t  _Nullable context, _Bool is_complete, nw_error_t  _Nullable err) {
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;
        if ( err ) {
            [self _closeConnectionWithError:@"Data receive failed."];
            return;
        }
        
        if ( self->mClosed ) {
            return;
        }
        
        [self _processRequestWithData:content];
    }];
}

- (void)_closeConnectionWithError:(NSString * _Nullable)desc {
    NSMutableString *message = [NSMutableString.alloc init];
    [message appendString:@"HTTP/1.1 500 Internal Server Error\r\n"];
    [message appendString:@"Content-Length: 0\r\n"];
    [message appendString:@"Connection: close\r\n"];
    if ( desc ) {
        [message appendFormat:@"MC-Error-Message: %@\r\n", desc];
    }
    [message appendString:@"\r\n"];
    
    dispatch_data_t content = [mConnection createDataWithString:message];
    __weak typeof(self) _self = self;
    [mConnection sendData:content context:NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT isComplete:YES completion:^(nw_error_t  _Nullable error) {
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;
        [self _close];
    }];
}

- (void)_close {
    if ( mClosed ) {
        return;
    }
    
    mClosed = YES;
    if ( mTask ) {
        [mTask close];
        mTask = nil;
    }
    [mConnection close];
    mStrongSelf = nil;
}

- (void)_processRequestWithData:(dispatch_data_t)content {
    NSError *error = nil;
    MCHttpRequest *req = [MCHttpRequest parseRequestWithData:content error:&error];
    if ( req == nil ) {
        [self _closeConnectionWithError:error.userInfo[NSLocalizedDescriptionKey]];
        return;
    }
    
    if ( [MCPin isPinReq:req] ) {
        [self _sendPinResponse];
        return;
    }
    
    NSString *range = req.headers[@"Range"];
    if ( range ) {
        if ( ![MCHttpRequestRange parseRequestRangeWithHeader:range error:&error] ) {
            [self _closeConnectionWithError:error.userInfo[NSLocalizedDescriptionKey]];
            return;
        }
    }
    
    NSString *host = req.headers[@"Host"];
    NSString *target = req.requestTarget;
    NSString *url = [NSString stringWithFormat:@"http://%@%@", host, target];
    NSMutableURLRequest *proxyRequest = [NSMutableURLRequest.alloc initWithURL:[NSURL URLWithString:url]];
    
    NSMutableDictionary<NSString *, NSString *> *headers = [req.headers mutableCopy];
    [headers removeObjectForKey:@"Host"];
    [headers removeObjectForKey:@"User-Agent"];
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
        [proxyRequest setValue:obj forHTTPHeaderField:key];
    }];
    
    mTask = [MCSProxyTask.alloc initWithRequest:proxyRequest delegate:self];
    [mTask prepare];
}

#pragma mark - MCSProxyTaskDelegate

- (void)task:(id<MCSProxyTask>)task didReceiveResponse:(id<MCSResponse>)response {
    dispatch_async(mConnection.queue, ^{
        [self _onDataSendable];
    });
}

- (void)task:(id<MCSProxyTask>)task hasAvailableDataWithLength:(NSUInteger)length {
    dispatch_async(mConnection.queue, ^{
        [self _onDataSendable];
    });
}

- (void)task:(id<MCSProxyTask>)task didAbortWithError:(nullable NSError *)error {
    dispatch_async(mConnection.queue, ^{
        [self _close];
    });
}

#pragma mark - name

- (void)_onDataSendable {
    if ( mSending || mClosed ) {
        return;
    }
    
    if ( mTask.isDone ) {
        [self _close];
        return;
    }
    
    if ( mTask.isAborted ) {
        return;
    }
    
    if ( !mHeaderHasSent ) {
        if ( !mTask.response ) {
            return;
        }
        
        mSending = YES;
        id<MCSResponse> response = mTask.response;
        NSMutableString *message = [NSMutableString.alloc init];
        // 206
        if ( response.range.length > 0 ) {
            [message appendString:@"HTTP/1.1 206 OK\r\n"];
            [message appendString:@"Server: localhost\r\n"];
            [message appendFormat:@"Content-Type: %@\r\n", response.contentType ?: @"application/octet-stream"];
            [message appendString:@"Accept-Ranges: bytes\r\n"];
            [message appendFormat:@"Content-Range: bytes %lu-%lu/%lu\r\n", response.range.location, NSMaxRange(response.range) - 1, response.totalLength];
            [message appendString:@"\r\n"];
        }
        // 200
        else {
            [message appendString:@"HTTP/1.1 200 OK\r\n"];
            [message appendString:@"Server: localhost\r\n"];
            [message appendFormat:@"Content-Type: %@\r\n", response.contentType ?: @"application/octet-stream"];
            [message appendString:@"Accept-Ranges: bytes\r\n"];
            if ( response.totalLength != NSUIntegerMax ) {
                [message appendFormat:@"Content-Length: %lu\r\n", response.totalLength];
            }
            [message appendString:@"\r\n"];
        }
        dispatch_data_t content = [mConnection createDataWithString:message];
        __weak typeof(self) _self = self;
        [mConnection sendData:content context:NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT isComplete:NO completion:^(nw_error_t  _Nullable error) {
            __strong typeof(_self) self = _self;
            if ( self == nil ) return;
            self->mHeaderHasSent = error == nil;
            [self _onDataSendCompleteWithError:error];
        }];
        
        return; // return;
    }
    
    NSData *data = [mTask readDataOfLength:8 * 1024];
    if ( data == NULL ) {
        return;
    }
    
    mSending = YES;
    dispatch_data_t content = [mConnection createData:data];
    __weak typeof(self) _self = self;
    [mConnection sendData:content context:NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT isComplete:mTask.isDone completion:^(nw_error_t  _Nullable error) {
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;
        [self _onDataSendCompleteWithError:error];
    }];
}

- (void)_onDataSendCompleteWithError:(nw_error_t _Nullable)error {
    if ( error ) {
        [self _close];
        return;
    }
    
    dispatch_async(self->mConnection.queue, ^{
        self->mSending = NO;
        [self _onDataSendable];
    });
}

- (void)_sendPinResponse {
    NSString *message = @"HTTP/1.1 200 OK\r\n\r\n";
    dispatch_data_t content = [mConnection createDataWithString:message];
    __weak typeof(self) _self = self;
    [mConnection sendData:content context:NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT isComplete:YES completion:^(nw_error_t  _Nullable error) {
        __strong typeof(_self) self = _self;
        if ( self == nil ) return;
        [self _close];
    }];
}
@end
