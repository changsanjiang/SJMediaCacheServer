//
//  FILEPrefetcher.m
//  CocoaAsyncSocket
//
//  Created by BlueDancer on 2020/6/11.
//

#import "FILEPrefetcher.h"
#import "MCSLogger.h"
#import "MCSAssetManager.h"
#import "NSURLRequest+MCS.h"
#import "MCSUtils.h"
#import "MCSError.h"
#import "FILEAsset.h"

@interface FILEPrefetcher () <MCSAssetReaderDelegate>
@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isCompleted;

@property (nonatomic, strong, nullable) id<MCSAssetReader> reader;
@property (nonatomic) NSUInteger loadedLength;

@property (nonatomic, strong) NSURL *URL;
@property (nonatomic) NSUInteger preloadSize;
@property (nonatomic) float progress;
@end

@implementation FILEPrefetcher
@synthesize delegate = _delegate;

- (instancetype)initWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes delegate:(nullable id<MCSPrefetcherDelegate>)delegate {
    self = [super init];
    if ( self ) {
        _delegate = delegate;
        _URL = URL;
        _preloadSize = bytes;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)URL delegate:(nullable id<MCSPrefetcherDelegate>)delegate {
    return [self initWithURL:URL preloadSize:NSNotFound delegate:delegate];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { preloadSize: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)self.preloadSize];
}

- (void)dealloc {
    MCSPrefetcherDebugLog(@"%@: <%p>.dealloc;\n", NSStringFromClass(self.class), self);
}

- (float)progress {
    @synchronized (self) {
        return _progress;
    }
}

#pragma mark - mark

- (void)prepare {
    @synchronized (self) {
        if ( _isCompleted || _isCalledPrepare )
             return;
         
         MCSPrefetcherDebugLog(@"%@: <%p>.prepare { preloadSize: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)_preloadSize);

         _isCalledPrepare = YES;
        
        FILEAsset *asset = [MCSAssetManager.shared assetWithURL:_URL];
        if ( asset == nil || ![asset isKindOfClass:FILEAsset.class] ) {
            _isCompleted = YES;
            [_delegate prefetcher:self didCompleteWithError:[NSError mcs_errorWithCode:MCSAbortError userInfo:@{
                MCSErrorUserInfoObjectKey : self,
                MCSErrorUserInfoReasonKey : [NSString stringWithFormat:@"无效的预加载请求: URL=%@", _URL]
            }]];
            return;
        }
    
        if ( asset.isStored ) {
            _isCompleted = YES;
            _progress = 1;
            [_delegate prefetcher:self didCompleteWithError:nil];
            return;
        }
         
         NSURLRequest *request = [NSURLRequest mcs_requestWithURL:_URL range:NSMakeRange(0, _preloadSize)];
         _reader = [MCSAssetManager.shared readerWithRequest:request networkTaskPriority:0 delegate:self];
         [_reader prepare];
    }
}

- (void)cancel {
    @synchronized (self) {
        [self _cancel];
    }
}

#pragma mark -

- (void)reader:(id<MCSAssetReader>)reader didReceiveResponse:(id<MCSResponse>)response {
    /* nothing */
}

- (void)reader:(nonnull id<MCSAssetReader>)reader hasAvailableDataWithLength:(NSUInteger)length {
    @synchronized (self) {
        if ( _isCompleted ) return;
        
        if ( [reader seekToOffset:reader.offset + length] ) {
            _loadedLength += length;
            
            float progress = _loadedLength * 1.0 / reader.response.range.length;
            if ( progress >= 1 ) progress = 1;
            _progress = progress;
            
            MCSPrefetcherDebugLog(@"%@: <%p>.preload { preloadSize: %lu, total: %lu, progress: %f };\n", NSStringFromClass(self.class), self, (unsigned long)_preloadSize, (unsigned long)reader.response.totalLength, progress);
                        
            if ( _delegate != nil ) {
                [_delegate prefetcher:self progressDidChange:progress];
            }
            
            if ( _reader.status == MCSReaderStatusFinished ) {
                [self _completeWithError:nil];
            }
        }
    }
}

- (void)reader:(id<MCSAssetReader>)reader didAbortWithError:(nullable NSError *)error {
    @synchronized (self) {
        [self _completeWithError:error ?: [NSError mcs_errorWithCode:MCSAbortError userInfo:@{
            MCSErrorUserInfoObjectKey : self,
            MCSErrorUserInfoReasonKey : @"预加载已被终止!"
        }]];
    }
}

#pragma mark - unlocked

/// unlocked
- (void)_completeWithError:(NSError *_Nullable)error {
    if ( !_isCompleted ) {
        _isCompleted = YES;
        
    #ifdef DEBUG
        if ( error == nil )
            MCSPrefetcherDebugLog(@"%@: <%p>.done;\n", NSStringFromClass(self.class), self);
        else
            MCSPrefetcherErrorLog(@"%@:  <%p>.error { error: %@ };\n", NSStringFromClass(self.class), self, error);
    #endif
        
        if ( _delegate != nil ) {
            [_delegate prefetcher:self didCompleteWithError:error];
        }
    }
}

/// unlocked
- (void)_cancel {
    if ( !_isCompleted ) {
        _isCompleted = YES;
        
        NSError *error = [NSError mcs_errorWithCode:MCSCancelledError userInfo:@{
            MCSErrorUserInfoObjectKey : self,
            MCSErrorUserInfoReasonKey : @"预加载被取消"
        }];
        [_reader abortWithError:error];
        _reader = nil;
        
        MCSPrefetcherDebugLog(@"%@: <%p>.cancel;\n", NSStringFromClass(self.class), self);
        
        if ( _delegate != nil ) {
            [_delegate prefetcher:self didCompleteWithError:error];
        }
    }
}
@end
