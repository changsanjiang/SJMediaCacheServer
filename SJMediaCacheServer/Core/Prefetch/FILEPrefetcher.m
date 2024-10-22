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

typedef NS_ENUM(NSUInteger, FILEPrefetcherState) {
    FILEPrefetcherStateUnknown,
    FILEPrefetcherStatePreparing,
    FILEPrefetcherStatePrefetching,
    FILEPrefetcherStateCompleted
};

@interface FILEPrefetcher () <MCSAssetReaderDelegate> {
    NSURL *mURL;
    
    FILEPrefetcherState mState;
    __weak id<MCSPrefetcherDelegate> _Nullable mDelegate;

    id<MCSAssetReader> mCurReader;

    NSUInteger mPreloadSize;
    UInt64 mPrefetchedLength;
    
    NSUInteger mSegmentSize; // 每次分段请求大小;
    
    float mProgress;
}
@end

@implementation FILEPrefetcher
@synthesize delegate = _delegate;

- (instancetype)initWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes delegate:(nullable id<MCSPrefetcherDelegate>)delegate {
    NSParameterAssert(bytes != 0);
    self = [super init];
    mDelegate = delegate;
    mURL = URL;
    mPreloadSize = bytes;
    return self;
}

- (instancetype)initWithURL:(NSURL *)URL delegate:(nullable id<MCSPrefetcherDelegate>)delegate {
    return [self initWithURL:URL preloadSize:NSNotFound delegate:delegate];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { preloadSize: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)mPreloadSize];
}

- (void)dealloc {
    MCSPrefetcherDebugLog(@"%@: <%p>.dealloc;\n", NSStringFromClass(self.class), self);
}

- (float)progress {
    @synchronized (self) {
        return mProgress;
    }
}

- (id<MCSPrefetcherDelegate>)delegate {
    return mDelegate;
}

#pragma mark - mark

- (void)prepare {
    @synchronized (self) {
        switch (mState) {
            case FILEPrefetcherStateUnknown: {
                mState = FILEPrefetcherStatePreparing;
                
                MCSPrefetcherDebugLog(@"%@: <%p>.prepare { preloadSize: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)mPreloadSize);
                
                FILEAsset *asset = [MCSAssetManager.shared assetWithURL:mURL];
                if ( asset == nil || ![asset isKindOfClass:FILEAsset.class] ) {
                    [_delegate prefetcher:self didCompleteWithError:[NSError mcs_errorWithCode:MCSAbortError userInfo:@{
                        MCSErrorUserInfoObjectKey : self,
                        MCSErrorUserInfoReasonKey : [NSString stringWithFormat:@"无效的预加载请求: URL=%@", mURL]
                    }]];
                    return;
                }
                
                if ( asset.isStored ) {
                    mProgress = 1;
                    [_delegate prefetcher:self didCompleteWithError:nil];
                    return;
                }
                
                NSURLRequest *request = [NSURLRequest mcs_requestWithURL:mURL range:NSMakeRange(0, 2)]; // 2 test file size
                mCurReader = [MCSAssetManager.shared readerWithRequest:request networkTaskPriority:0 delegate:self];
                [mCurReader prepare];
            }
                break;
            case FILEPrefetcherStatePreparing:
            case FILEPrefetcherStatePrefetching:
            case FILEPrefetcherStateCompleted:
                break;
        }
    }
}

- (void)cancel {
    @synchronized (self) {
        switch (mState) {
            case FILEPrefetcherStateUnknown:
            case FILEPrefetcherStatePreparing:
            case FILEPrefetcherStatePrefetching: {
                mState = FILEPrefetcherStateCompleted;
                if ( mCurReader != nil ) [mCurReader abortWithError:nil];
                [self _notifyComplete:[NSError mcs_errorWithCode:MCSCancelledError userInfo:@{
                    MCSErrorUserInfoObjectKey : self,
                    MCSErrorUserInfoReasonKey : @"预加载被取消了"
                }]];
            }
                break;
            case FILEPrefetcherStateCompleted:
                break;
        }
    }
}

#pragma mark -

- (void)reader:(id<MCSAssetReader>)reader didReceiveResponse:(id<MCSResponse>)response {
    NSUInteger totalLength = response.totalLength;
    mPreloadSize = MIN(mPreloadSize > 0 ? mPreloadSize : NSUIntegerMax, totalLength); // fix preloadSize
    mSegmentSize = MAX(10 * 1024 * 1024, mPreloadSize * 0.05); // minSegmentSize: 10M
    mState = FILEPrefetcherStatePrefetching;
}

- (void)reader:(nonnull id<MCSAssetReader>)reader hasAvailableDataWithLength:(NSUInteger)length {
    @synchronized (self) {
        switch (mState) {
            case FILEPrefetcherStateUnknown:
            case FILEPrefetcherStateCompleted:
            case FILEPrefetcherStatePreparing:
                break;
            case FILEPrefetcherStatePrefetching: {
                if ( [reader seekToOffset:reader.offset + length] ) {
                    mPrefetchedLength += length;
                    
                    float progress = mPrefetchedLength * 1.0 / mPreloadSize; // now preloadSize available
                    if ( progress >= 1 ) progress = 1;
                    mProgress = progress;
                    
                    MCSPrefetcherDebugLog(@"%@: <%p>.preload { preloadSize: %lu, total: %lu, progress: %f };\n", NSStringFromClass(self.class), self, (unsigned long)mPreloadSize, (unsigned long)reader.response.totalLength, progress);
                                
                    if ( _delegate != nil ) {
                        [_delegate prefetcher:self progressDidChange:progress];
                    }
                    
                    if ( mCurReader.status == MCSReaderStatusFinished ) {
                        [self _readDidFinish:reader];
                    }
                }
            }
                break;
        }
    }
}

- (void)reader:(id<MCSAssetReader>)reader didAbortWithError:(nullable NSError *)error {
    @synchronized (self) {
        switch (mState) {
            case FILEPrefetcherStateUnknown:
            case FILEPrefetcherStatePreparing:
            case FILEPrefetcherStatePrefetching: {
                mState = FILEPrefetcherStateCompleted;
                [self _notifyComplete:error ?: [NSError mcs_errorWithCode:MCSAbortError userInfo:@{
                    MCSErrorUserInfoObjectKey : self,
                    MCSErrorUserInfoReasonKey : @"预加载已被终止!"
                }]];
            }
                break;
            case FILEPrefetcherStateCompleted:
                break;
        }
    }
}

#pragma mark - unlocked

- (void)_readDidFinish:(id<MCSAssetReader>)reader {
    if ( mPrefetchedLength >= mPreloadSize ) {
        mState = FILEPrefetcherStateCompleted;
        [self _notifyComplete:nil];
        return;
    }
    
    NSUInteger length = MIN(mSegmentSize, mPreloadSize - mPrefetchedLength);
    NSRange nextRange = NSMakeRange(mPrefetchedLength, length);
    NSURLRequest *request = [NSURLRequest mcs_requestWithURL:mURL range:nextRange];
    mCurReader = [MCSAssetManager.shared readerWithRequest:request networkTaskPriority:0 delegate:self];
    [mCurReader prepare];
}

- (void)_notifyComplete:(NSError *_Nullable)error {
#ifdef DEBUG
    if ( error == nil )
        MCSPrefetcherDebugLog(@"%@: <%p>.done;\n", NSStringFromClass(self.class), self);
    else
        MCSPrefetcherErrorLog(@"%@:  <%p>.error { error: %@ };\n", NSStringFromClass(self.class), self, error);
#endif
    
    [mDelegate prefetcher:self didCompleteWithError:error];
}
@end
