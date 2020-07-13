//
//  MCSPrefetcherManager.m
//  CocoaAsyncSocket
//
//  Created by BlueDancer on 2020/6/12.
//

#import "MCSPrefetcherManager.h"
#import "MCSHLSPrefetcher.h"
#import "MCSVODPrefetcher.h"
#import "MCSURLRecognizer.h"

@interface MCSPrefetchOperation : NSOperation<MCSPrefetchTask>
- (instancetype)initWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes progress:(void(^_Nullable)(float progress))progressBlock completed:(void(^_Nullable)(NSError *_Nullable error))completionBlock;

@property (nonatomic, readonly) NSUInteger preloadSize;
@property (nonatomic, strong, readonly) NSURL *URL;
@property (nonatomic, copy, readonly, nullable) void(^mcs_progressBlock)(float progress);
@property (nonatomic, copy, readonly, nullable) void(^mcs_completionBlock)(NSError *_Nullable error);

- (void)cancel;
@end

@interface MCSPrefetchOperation ()<MCSPrefetcherDelegate> {
    NSRecursiveLock *_lock;
    BOOL _isFinished;
    BOOL _isCancelled;
    BOOL _isExecuting;
    id<MCSPrefetcher> _prefetcher;
}
@end

@implementation MCSPrefetchOperation
@synthesize cancelled = _cancelled;
@synthesize executing = _executing;
@synthesize finished = _finished;

- (instancetype)initWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes progress:(void(^_Nullable)(float progress))progressBlock completed:(void(^_Nullable)(NSError *_Nullable error))completionBlock {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _preloadSize = bytes;
        _mcs_progressBlock = progressBlock;
        _mcs_completionBlock = completionBlock;
        _lock = NSRecursiveLock.alloc.init;
    }
    return self;
}

- (void)prefetcher:(id<MCSPrefetcher>)prefetcher progressDidChange:(float)progress {
    if ( _mcs_progressBlock != nil ) {
        _mcs_progressBlock(progress);
    }
}

- (void)prefetcher:(id<MCSPrefetcher>)prefetcher didCompleteWithError:(NSError *_Nullable)error {
    [self _lock:^{
        [self _completeOperationIfExecuting];
    }];
    if ( _mcs_completionBlock != nil ) {
        _mcs_completionBlock(error);
    }
}

#pragma mark -
 
- (void)start {
    [self _lock:^{
        [self willChangeValueForKey:@"isExecuting"];
        self->_isExecuting = YES;
        [self didChangeValueForKey:@"isExecuting"];
        
        if ( self->_isCancelled || self->_URL == nil ) {
            [self _completeOperationIfExecuting];
            return;
        }
        
        MCSResourceType type = [MCSURLRecognizer.shared resourceTypeForURL:self->_URL];
        id<MCSPrefetcherDelegate> delegate = self->_mcs_progressBlock != nil || self->_mcs_completionBlock != nil ? self : nil;
        switch ( type ) {
            case MCSResourceTypeVOD:
                self->_prefetcher = [MCSVODPrefetcher.alloc initWithURL:self->_URL preloadSize:self->_preloadSize delegate:delegate delegateQueue:dispatch_get_main_queue()];
                break;
            case MCSResourceTypeHLS:
                self->_prefetcher = [MCSHLSPrefetcher.alloc initWithURL:self->_URL preloadSize:self->_preloadSize delegate:delegate delegateQueue:dispatch_get_main_queue()];
                break;
        }
        [self->_prefetcher prepare];
    }];
}

- (void)cancel {
    [self _lock:^{
        if ( self->_isCancelled || self->_isFinished )
            return;
        
        self->_isCancelled = YES;
        
        [self _completeOperationIfExecuting];
    }];
}

#pragma mark -

- (void)_completeOperationIfExecuting {
    if ( !self->_isExecuting )
        return;
    
    if ( self->_isFinished )
        return;
    
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    
    [self->_prefetcher close];
    self->_prefetcher = nil;
    self->_isExecuting = NO;
    self->_isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

#pragma mark -

- (BOOL)isAsynchronous {
    return YES;
}

- (BOOL)isExecuting {
    __block BOOL isExecuting = NO;
    [self _lock:^{
        isExecuting = self->_isExecuting;
    }];
    return isExecuting;
}

- (BOOL)isFinished {
    __block BOOL isFinished = NO;
    [self _lock:^{
        isFinished = self->_isFinished;
    }];
    return isFinished;
}

- (BOOL)isCancelled {
    return NO;
}

#pragma mark -

- (void)_lock:(void(^)(void))block {
    [_lock lock];
    block();
    [_lock unlock];
}
@end



@interface MCSPrefetcherManager ()
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@end

@implementation MCSPrefetcherManager
+ (instancetype)shared {
    static id obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[self alloc] init];
    });
    return obj;
}

- (instancetype)init {
    self = [super init];
    if ( self ) {
        _operationQueue = NSOperationQueue.alloc.init;
        _operationQueue.maxConcurrentOperationCount = 3;
        _operationQueue.qualityOfService = NSQualityOfServiceBackground;
    }
    return self;
}

- (void)setMaxConcurrentPrefetchCount:(NSInteger)maxConcurrentPrefetchCount {
    _operationQueue.maxConcurrentOperationCount = maxConcurrentPrefetchCount;
}

- (NSInteger)maxConcurrentPrefetchCount {
    return _operationQueue.maxConcurrentOperationCount;
}

- (id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL preloadSize:(NSUInteger)preloadSize {
    return [self prefetchWithURL:URL preloadSize:preloadSize progress:nil completed:nil];
}

- (id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL preloadSize:(NSUInteger)preloadSize progress:(void(^_Nullable)(float progress))progressBlock completed:(void(^_Nullable)(NSError *_Nullable error))completionBlock {
    MCSPrefetchOperation *operation = [MCSPrefetchOperation.alloc initWithURL:URL preloadSize:preloadSize progress:progressBlock completed:completionBlock];
    [_operationQueue addOperation:operation];
    return operation;
}

- (void)cancelAllPrefetchTasks {
    [_operationQueue cancelAllOperations];
}
@end
