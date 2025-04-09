//
//  MCPin.m
//  SJMediaCacheServer
//
//  Created by db on 2025/3/10.
//

#import "MCPin.h"
#import "MCHttpRequest.h"
#import "MCSLogger.h"

@interface MCTimer : NSObject
- (instancetype)initWithQueue:(dispatch_queue_t)queue start:(NSTimeInterval)start interval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(MCTimer *timer))block;

@property (nonatomic, readonly, getter=isValid) BOOL valid;

- (void)resume;
- (void)suspend;
- (void)invalidate;
@end
 
@implementation MCTimer {
    dispatch_semaphore_t _semaphore;
    dispatch_source_t _timer;
    NSTimeInterval _timeInterval;
    BOOL _repeats;
    BOOL _valid;
    BOOL _suspend;
}

/// @param start 启动后延迟多少秒回调block
- (instancetype)initWithQueue:(dispatch_queue_t)queue start:(NSTimeInterval)start interval:(NSTimeInterval)interval repeats:(BOOL)repeats block:(void (^)(MCTimer *timer))block {
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

#pragma mark - MCPin

@implementation MCPin {
    NSURL *mReqURL; // 请求地址
    NSTimeInterval mReqInterval; // 请求间隔
    NSTimeInterval mReqTimeoutInterval; // 2s; 超时;
    NSInteger mReqAttempts; // 3次; 失败重试次数;
    void(^mFailureHandler)(void);
    MCTimer *mTimer;
}

+ (BOOL)isPinReq:(MCHttpRequest *)req {
    NSString *flag = [req.method isEqualToString:@"HEAD"] ? req.headers[@"MC-PIN-REQ"] : nil;
    return flag && [flag isEqualToString:@"1"];
}

- (instancetype)initWithInterval:(NSTimeInterval)interval failureHandler:(void(^)(void))failureHandler {
    self = [super init];
    mReqInterval = interval;
    mReqTimeoutInterval = 2;
    mReqAttempts = 3;
    mFailureHandler = failureHandler;
    return self;
}

- (void)dealloc {
    if ( mTimer ) [mTimer invalidate];
}

- (void)startWithPort:(uint16_t)port {
    @synchronized (self) {
        mReqURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%hu", port]];
        
        if ( mTimer == nil ) {
            __weak typeof(self) _self = self;
            mTimer = [MCTimer.alloc initWithQueue:dispatch_get_global_queue(0, 0) start:mReqInterval interval:mReqInterval repeats:YES block:^(MCTimer *timer) {
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
                                [self stop];
                                self->mFailureHandler();
                                return;
                            }
                            [timer resume];
                        }
                    }
                }];
            }];
            [mTimer resume];
            MCSHeartbeatDebugLog(@"%@<%p>: %d : %s\n", NSStringFromClass(self.class), self, __LINE__, sel_getName(_cmd));
        }
    }

}

- (void)stop {
    @synchronized (self) {
        if ( mTimer != nil ) {
            [mTimer invalidate];
            mTimer = nil;
            MCSHeartbeatDebugLog(@"%@<%p>: %d : %s\n", NSStringFromClass(self.class), self, __LINE__, sel_getName(_cmd));
        }
    }
}

#pragma mark -

- (void)sendHeartbeatWithCompletion:(void(^)(NSError *_Nullable error))completionHandler {
    [self sendHeartbeatWithRemainingRetries:mReqAttempts completion:completionHandler];
}

- (void)sendHeartbeatWithRemainingRetries:(NSInteger)remainingRetries completion:(void(^)(NSError *_Nullable error))completionHandler {
    NSMutableURLRequest *request = [NSMutableURLRequest.alloc initWithURL:mReqURL];
    request.HTTPMethod = @"HEAD";
    request.timeoutInterval = mReqTimeoutInterval;
    [request addValue:@"1" forHTTPHeaderField:@"MC-PIN-REQ"];
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        MCSHeartbeatDebugLog(@"%@<%p>: %d : %s, status=%ld, error=%@\n", NSStringFromClass(self.class), self, __LINE__, sel_getName(_cmd), [(NSHTTPURLResponse *)response statusCode], error);

        if ( error != nil && remainingRetries > 0 ) {
            [self sendHeartbeatWithRemainingRetries:remainingRetries - 1 completion:completionHandler];
            return;
        }
        completionHandler(error);
    }] resume];
}
@end
