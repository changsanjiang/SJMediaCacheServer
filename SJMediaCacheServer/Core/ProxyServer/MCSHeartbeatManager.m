//
//  MCSHeartbeatManager.m
//  SJMediaCacheServer
//
//  Created by db on 2024/10/11.
//

#import "MCSHeartbeatManager.h"
#import "HTTPMessage.h"
#import "MCSLogger.h"

@interface MCSTimer : NSObject
- (instancetype)initWithQueue:(dispatch_queue_t)queue start:(NSTimeInterval)start interval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(MCSTimer *timer))block;

@property (nonatomic, readonly, getter=isValid) BOOL valid;

- (void)resume;
- (void)suspend;
- (void)invalidate;
@end
 
@implementation MCSTimer {
    dispatch_semaphore_t _semaphore;
    dispatch_source_t _timer;
    NSTimeInterval _timeInterval;
    BOOL _repeats;
    BOOL _valid;
    BOOL _suspend;
}

/// @param start 启动后延迟多少秒回调block
- (instancetype)initWithQueue:(dispatch_queue_t)queue start:(NSTimeInterval)start interval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(MCSTimer *timer))block {
    self = [super init];
    if ( self ) {
        _repeats = repeats;
        _timeInterval = interval;
        _valid = YES;
        _suspend = YES;
        _semaphore = dispatch_semaphore_create(1);
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, (start * NSEC_PER_SEC)), (interval * NSEC_PER_SEC), 0);
        __weak typeof(self) _self = self;
        dispatch_source_set_event_handler(_timer, ^{
            __strong typeof(_self) self = _self;
            if ( self == nil ) return;
            block(self);
            if ( !repeats )
                [self invalidate];
        });
    }
    return self;
}

- (void)resume {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    if ( _valid && _suspend ) {
        _suspend = NO;
        dispatch_resume(_timer);
    }
    dispatch_semaphore_signal(_semaphore);
}

- (void)suspend {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    if ( _valid && !_suspend ) {
        _suspend = YES;
        dispatch_suspend(_timer);
    }
    dispatch_semaphore_signal(_semaphore);
}

- (void)invalidate {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    if ( _valid ) {
        dispatch_source_cancel(_timer);
        if ( _suspend )
            dispatch_resume(_timer);
        _timer = NULL;
        _valid = NO;
    }
    dispatch_semaphore_signal(_semaphore);
}

- (BOOL)isValid {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    BOOL isValid = _valid;
    dispatch_semaphore_signal(_semaphore);
    return isValid;
}

- (void)dealloc {
    [self invalidate];
}

@end

@implementation MCSHeartbeatManager {
    MCSTimer *mTimer;
    void(^mFailureHandler)(MCSHeartbeatManager *mgr);
}

- (instancetype)initWithInterval:(NSTimeInterval)heartbeatInterval failureHandler:(void(^)(MCSHeartbeatManager *mgr))block {
    self = [super init];
    mFailureHandler = block;
    _heartbeatInterval = heartbeatInterval ?: 5;
    _timeoutInterval = 2;
    _maxAttempts = 3;
    return self;
}

- (void)dealloc {
    [mTimer invalidate];
}

- (void)setHeartbeatInterval:(NSTimeInterval)heartbeatInterval {
    if ( _heartbeatInterval != heartbeatInterval ) {
        _heartbeatInterval = heartbeatInterval;
        @synchronized (self) {
            if ( mTimer != nil ) {
                [self stopHeartbeat];
                [self startHeartbeat];
            }
        }
    }
}

- (void)startHeartbeat {
    @synchronized (self) {
        if ( mTimer == nil ) {
            __weak typeof(self) _self = self;
            mTimer = [MCSTimer.alloc initWithQueue:dispatch_get_global_queue(0, 0) start:_heartbeatInterval interval:_heartbeatInterval repeats:YES block:^(MCSTimer *timer) {
                __strong typeof(_self) self = _self;
                if ( self == nil ) {
                    [timer invalidate];
                    return;
                }
                [timer suspend];
                @synchronized (self) { if ( timer != self->mTimer ) return; }
                [self sendHeartbeatWithCompletion:^(NSError * _Nullable error) {
                    __strong typeof(_self) self = _self;
                    if ( self == nil ) {
                        [timer invalidate];
                        return;
                    }
                    @synchronized (self) {
                        if ( timer == self->mTimer ) {
                            if ( error != nil ) {
                                [self stopHeartbeat];
                                self->mFailureHandler(self);
                                return;
                            }
                            [timer resume];
                        }
                    }
                }];
            }];
            [mTimer resume];
#ifdef DEBUG
            NSLog(@"%@<%p>: %d : %s", NSStringFromClass(self.class), self, __LINE__, sel_getName(_cmd));
#endif
        }
    }
}

- (void)stopHeartbeat {
    @synchronized (self) {
        if ( mTimer != nil ) {
            [mTimer invalidate];
            mTimer = nil;
#ifdef DEBUG
            NSLog(@"%@<%p>: %d : %s", NSStringFromClass(self.class), self, __LINE__, sel_getName(_cmd));
#endif
        }
    }
}

- (BOOL)isHeartBeatRequest:(HTTPMessage *)msg {
    return [msg.method isEqualToString: @"HEAD"] && [[msg headerField:@"MCS_PROXY_HEARTBEAT_FLAG"] isEqualToString:@"1"];
}

- (void)sendHeartbeatWithCompletion:(void(^)(NSError *_Nullable error))completionHandler {
    [self sendHeartbeatWithRemainingRetries:_maxAttempts completion:completionHandler];
}

- (void)sendHeartbeatWithRemainingRetries:(NSInteger)remainingRetries completion:(void(^)(NSError *_Nullable error))completionHandler {
    NSMutableURLRequest *request = [NSMutableURLRequest.alloc initWithURL:self.serverURL];
    request.HTTPMethod = @"HEAD";
    request.timeoutInterval = _timeoutInterval;
    [request addValue:@"1" forHTTPHeaderField:@"MCS_PROXY_HEARTBEAT_FLAG"];
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
#ifdef DEBUG
        NSLog(@"%@<%p>: %d : %s, status=%ld, error=%@", NSStringFromClass(self.class), self, __LINE__, sel_getName(_cmd), [(NSHTTPURLResponse *)response statusCode], error);
#endif
        if ( error != nil && remainingRetries > 0 ) {
            [self sendHeartbeatWithRemainingRetries:remainingRetries - 1 completion:completionHandler];
            return;
        }
        completionHandler(error);
    }] resume];
}
@end
