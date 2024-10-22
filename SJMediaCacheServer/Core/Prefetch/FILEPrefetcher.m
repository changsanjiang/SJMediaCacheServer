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

    NSUInteger mPrefetchSize;
    UInt64 mLength;
    
    NSUInteger mSegmentSize; // 每次分段请求大小;
    
    float mProgress;
}
@end

@implementation FILEPrefetcher
@synthesize delegate = _delegate;

- (instancetype)initWithURL:(NSURL *)URL prefetchSize:(NSUInteger)bytes delegate:(nullable id<MCSPrefetcherDelegate>)delegate {
    NSParameterAssert(bytes != 0);
    self = [super init];
    mDelegate = delegate;
    mURL = URL;
    mPrefetchSize = bytes;
    return self;
}

- (instancetype)initWithURL:(NSURL *)URL delegate:(nullable id<MCSPrefetcherDelegate>)delegate {
    return [self initWithURL:URL prefetchSize:NSNotFound delegate:delegate];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { prefetchSize: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)self.prefetchSize];
}

- (void)dealloc {
    MCSPrefetcherDebugLog(@"%@: <%p>.dealloc;\n", NSStringFromClass(self.class), self);
}

- (float)progress {
    @synchronized (self) {
        return mProgress;
    }
}

- (NSUInteger)prefetchSize {
    @synchronized (self) {
        return mPrefetchSize;
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
                
                MCSPrefetcherDebugLog(@"%@: <%p>.prepare { prefetchSize: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)mPrefetchSize);
                
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
    @synchronized (self) {
        switch (mState) {
            case FILEPrefetcherStatePreparing: {
                NSUInteger totalLength = response.totalLength;
                mPrefetchSize = MIN(mPrefetchSize > 0 ? mPrefetchSize : NSUIntegerMax, totalLength); // fix prefetchSize
                mSegmentSize = MAX(10 * 1024 * 1024, mPrefetchSize * 0.05); // minSegmentSize: 10M
                mState = FILEPrefetcherStatePrefetching;
            }
                break;
            case FILEPrefetcherStateUnknown:
            case FILEPrefetcherStatePrefetching:
            case FILEPrefetcherStateCompleted:
                break;
        }
    }
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
                    mLength += length;
                    
                    float progress = mLength * 1.0 / mPrefetchSize; // now prefetchSize available
                    if ( progress >= 1 ) progress = 1;
                    mProgress = progress;
                    
                    MCSPrefetcherDebugLog(@"%@: <%p>.preload { prefetchSize: %lu, total: %lu, progress: %f };\n", NSStringFromClass(self.class), self, (unsigned long)mPrefetchSize, (unsigned long)reader.response.totalLength, progress);
                                
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
    if ( mLength >= mPrefetchSize ) {
        mState = FILEPrefetcherStateCompleted;
        [self _notifyComplete:nil];
        return;
    }
    
    NSUInteger length = MIN(mSegmentSize, mPrefetchSize - mLength);
    NSRange nextRange = NSMakeRange(mLength, length);
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
