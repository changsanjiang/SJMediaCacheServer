//
//  MCSPrefetcherManager.m
//  CocoaAsyncSocket
//
//  Created by BlueDancer on 2020/6/12.
//

#import "MCSPrefetcherManager.h"
#import "HLSPrefetcher.h"
#import "FILEPrefetcher.h"
#import "MCSURL.h"

@interface MCSPrefetchOperation : NSOperation<MCSPrefetchTask>
- (instancetype)initWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes progress:(void(^_Nullable)(float progress))progressBlock completed:(void(^_Nullable)(NSError *_Nullable error))completionBlock;

- (instancetype)initWithURL:(NSURL *)URL numberOfPreloadedFiles:(NSUInteger)num progress:(void(^_Nullable)(float progress))progressBlock completed:(void(^_Nullable)(NSError *_Nullable error))completionBlock;

- (instancetype)initWithURL:(NSURL *)URL progress:(void(^_Nullable)(float progress))progressBlock completed:(void(^_Nullable)(NSError *_Nullable error))completionBlock;

@property (nonatomic, readonly) NSUInteger preloadSize;
@property (nonatomic, readonly) NSUInteger numberOfPreloadedFiles;
@property (nonatomic, strong, readonly) NSURL *URL;
@property (nonatomic, copy, readonly, nullable) void(^mcs_progressBlock)(float progress);
@property (nonatomic, copy, readonly, nullable) void(^mcs_completionBlock)(NSError *_Nullable error);

- (void)cancel;
@end

@interface MCSPrefetchOperation ()<MCSPrefetcherDelegate> {
    id<MCSPrefetcher> _prefetcher;
    BOOL _isPrefetchAllMode;
    BOOL _isCancelled;
    BOOL _isExecuting;
    BOOL _isFinished;
}
@end

@implementation MCSPrefetchOperation
@synthesize startedExecuteBlock = _startedExecuteBlock;
- (instancetype)initWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes progress:(void(^_Nullable)(float progress))progressBlock completed:(void(^_Nullable)(NSError *_Nullable error))completionBlock {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _preloadSize = bytes;
        _mcs_progressBlock = progressBlock;
        _mcs_completionBlock = completionBlock;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)URL numberOfPreloadedFiles:(NSUInteger)num progress:(void(^_Nullable)(float progress))progressBlock completed:(void(^_Nullable)(NSError *_Nullable error))completionBlock {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _numberOfPreloadedFiles = num;
        _mcs_progressBlock = progressBlock;
        _mcs_completionBlock = completionBlock;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)URL progress:(void(^_Nullable)(float progress))progressBlock completed:(void(^_Nullable)(NSError *_Nullable error))completionBlock {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _isPrefetchAllMode = YES;
        _mcs_progressBlock = progressBlock;
        _mcs_completionBlock = completionBlock;
    }
    return self;
}

- (void)prefetcher:(id<MCSPrefetcher>)prefetcher progressDidChange:(float)progress {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ( self->_mcs_progressBlock != nil ) {
            self->_mcs_progressBlock(progress);
        }
    });
}

- (void)prefetcher:(id<MCSPrefetcher>)prefetcher didCompleteWithError:(NSError *_Nullable)error {
    @synchronized (self) {
        [self _completeOperationIfExecuting];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if ( self->_mcs_completionBlock != nil ) {
            self->_mcs_completionBlock(error);
        }
    });
}

#pragma mark -
 
- (void)start {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    @synchronized (self) {
        if ( _isCancelled ) {
            [self _completeOperationIfExecuting];
            return;
        }
        
        MCSAssetType type = [MCSURL.shared assetTypeForURL:_URL];
        switch ( type ) {
            case MCSAssetTypeFILE: {
                _prefetcher = _isPrefetchAllMode || _numberOfPreloadedFiles != 0 ?
                    [FILEPrefetcher.alloc initWithURL:_URL delegate:self] :
                    [FILEPrefetcher.alloc initWithURL:_URL preloadSize:_preloadSize delegate:self];
            }
                break;
            case MCSAssetTypeHLS: {
                if ( _isPrefetchAllMode ) {
                    _prefetcher = [HLSPrefetcher.alloc initWithURL:_URL delegate:self];
                }
                else {
                    _prefetcher = _numberOfPreloadedFiles != 0 ?
                        [HLSPrefetcher.alloc initWithURL:_URL numberOfPreloadedFiles:_numberOfPreloadedFiles delegate:self] :
                        [HLSPrefetcher.alloc initWithURL:_URL preloadSize:_preloadSize delegate:self];
                }
            }
                break;
        }
        [_prefetcher prepare];
        
        if ( _startedExecuteBlock != nil ) _startedExecuteBlock(self);
    }
}

- (void)cancel {
    @synchronized (self) {
        if ( _isFinished ) return;
        _isCancelled = YES;
        [self _completeOperationIfExecuting];
    }
}

#pragma mark -

- (void)_completeOperationIfExecuting {
    if ( !_isExecuting || _isFinished ) return;
    
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];

    if ( _isCancelled ) [_prefetcher cancel];
    _prefetcher = nil;
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

#pragma mark -

- (BOOL)isAsynchronous {
    return YES;
}

- (BOOL)isExecuting {
    @synchronized (self) {
        return _isExecuting;
    }
}

- (BOOL)isFinished {
    @synchronized (self) {
        return _isFinished;
    }
}

- (BOOL)isCancelled {
    return NO;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { isExecuting: %d, isFinished: %d, isCancelled: %d };", NSStringFromClass(self.class), self, _isExecuting, _isFinished, _isCancelled];
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
        _operationQueue.maxConcurrentOperationCount = 1;
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

- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL  progress:(void(^_Nullable)(float progress))progressBlock completed:(void(^_Nullable)(NSError *_Nullable error))completionBlock {
    if ( URL == nil ) return nil;
    MCSPrefetchOperation *operation = [MCSPrefetchOperation.alloc initWithURL:URL progress:progressBlock completed:completionBlock];
    [_operationQueue addOperation:operation];
    return operation;
}

- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL preloadSize:(NSUInteger)preloadSize {
    return [self prefetchWithURL:URL preloadSize:preloadSize progress:nil completed:nil];
}

- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL preloadSize:(NSUInteger)preloadSize progress:(void(^_Nullable)(float progress))progressBlock completed:(void(^_Nullable)(NSError *_Nullable error))completionBlock {
    if ( URL == nil || preloadSize == 0 ) return nil;
    MCSPrefetchOperation *operation = [MCSPrefetchOperation.alloc initWithURL:URL preloadSize:preloadSize progress:progressBlock completed:completionBlock];
    [_operationQueue addOperation:operation];
    return operation;
}

- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL numberOfPreloadedFiles:(NSUInteger)num progress:(void(^_Nullable)(float progress))progressBlock completed:(void(^_Nullable)(NSError *_Nullable error))completionBlock {
    if ( URL == nil || num == 0 ) return nil;
    MCSPrefetchOperation *operation = [MCSPrefetchOperation.alloc initWithURL:URL numberOfPreloadedFiles:num progress:progressBlock completed:completionBlock];
    [_operationQueue addOperation:operation];
    return operation;
}

- (void)cancelAllPrefetchTasks {
    [_operationQueue cancelAllOperations];
}
@end
