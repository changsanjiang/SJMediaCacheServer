//
//  HLSPrefetcher.m
//
//  Created by BlueDancer on 2020/6/11.
//

#import "HLSPrefetcher.h"
#import "MCSLogger.h"
#import "MCSAssetManager.h"
#import "MCSError.h"
#import "HLSAsset.h"

typedef NS_ENUM(NSUInteger, HLSPrefetcherState) {
    HLSPrefetcherStateUnknown,
    HLSPrefetcherStatePreparing,
    HLSPrefetcherStatePrefetching,
    HLSPrefetcherStateCompleted
};

@interface HLSPrefetcher ()<MCSAssetReaderDelegate, MCSPrefetcherDelegate> {
    NSURL *mURL;
    
    HLSPrefetcherState mState;
    __weak id<MCSPrefetcherDelegate> _Nullable mDelegate;

    id<MCSAssetReader> _Nullable mCurReader;
    
    NSUInteger mPrefetchFileCount; // num mode; NSNotFound to prefetch all files;

    NSUInteger mPrefetchSize; // size mode;
    UInt64 mLength; // size mode segments length

    NSUInteger mNextItemIndex;
    NSUInteger mNextSegmentIndex;
 
    NSArray<id<MCSPrefetcher>> *_Nullable mAssociatedAssetPrefechers; // variant stream and renditions
    
    float mProgress;
}
@end

@implementation HLSPrefetcher

- (instancetype)initWithURL:(NSURL *)URL prefetchSize:(NSUInteger)bytes delegate:(nullable id<MCSPrefetcherDelegate>)delegate {
    NSParameterAssert(bytes != 0);
    return [self initWithURL:URL prefetchFileCount:0 prefetchSize:bytes delegate:delegate];
}

- (instancetype)initWithURL:(NSURL *)URL prefetchFileCount:(NSUInteger)num delegate:(nullable id<MCSPrefetcherDelegate>)delegate {
    return [self initWithURL:URL prefetchFileCount:num prefetchSize:0 delegate:delegate];
}

- (instancetype)initWithURL:(NSURL *)URL delegate:(nullable id<MCSPrefetcherDelegate>)delegate {
    return [self initWithURL:URL prefetchFileCount:NSNotFound prefetchSize:0 delegate:delegate];
}

- (instancetype)initWithURL:(NSURL *)URL
           prefetchFileCount:(NSUInteger)prefetchFileCount
                prefetchSize:(NSUInteger)prefetchSize
                   delegate:(nullable id<MCSPrefetcherDelegate>)delegate {
    self = [super init];
    mURL = URL;
    mPrefetchFileCount = prefetchFileCount;
    mPrefetchSize = prefetchSize;
    mDelegate = delegate;
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { URL: %@, prefetchSize: %lu, prefetchFileCount: %lu, progress: %f };\n", NSStringFromClass(self.class), self, mURL, (unsigned long)mPrefetchSize, (unsigned long)mPrefetchFileCount, self.progress];
}

- (nullable id<MCSPrefetcherDelegate>)delegate {
    return mDelegate;
}

- (float)progress {
    @synchronized (self) {
        return mProgress;
    }
}

- (void)dealloc {
    MCSPrefetcherDebugLog(@"%@: <%p>.dealloc;\n", NSStringFromClass(self.class), self);
}

- (void)prepare {
    @synchronized (self) {
        switch (mState) {
            case HLSPrefetcherStateUnknown: {
                mState = HLSPrefetcherStatePreparing;
                
                MCSPrefetcherDebugLog(@"%@: <%p>.prepare { URL: %@, prefetchSize: %lu, prefetchFileCount: %lu };\n", mURL, NSStringFromClass(self.class), self, (unsigned long)mPrefetchSize, (unsigned long)mPrefetchFileCount);
                
                HLSAsset *asset = [MCSAssetManager.shared assetWithURL:mURL];
                if ( asset == nil || ![asset isKindOfClass:HLSAsset.class] ) {
                    mState = HLSPrefetcherStateCompleted;
                    [self _notifyComplete:[NSError mcs_errorWithCode:MCSAbortError userInfo:@{
                        MCSErrorUserInfoObjectKey : self,
                        MCSErrorUserInfoReasonKey : [NSString stringWithFormat:@"无效的预加载请求: URL=%@", mURL]
                    }]];
                    return;
                }
            
                if ( asset.isStored ) {
                    mState = HLSPrefetcherStateCompleted;
                    mProgress = 1;
                    [self _notifyComplete:nil];
                    return;
                }

                NSURL *proxyURL = [MCSURL.shared generateProxyURLFromURL:mURL];
                NSURLRequest *proxyRequest = [NSURLRequest.alloc initWithURL:proxyURL];
                // playlist reader first
                mCurReader = [MCSAssetManager.shared readerWithRequest:proxyRequest networkTaskPriority:0 delegate:self];
                if ( mCurReader.contentDataType != MCSDataTypeHLSPlaylist ) {
                    mState = HLSPrefetcherStateCompleted;
                    [mCurReader abortWithError:nil];
                    [self _notifyComplete:[NSError mcs_errorWithCode:MCSAbortError userInfo:@{
                        MCSErrorUserInfoObjectKey : self,
                        MCSErrorUserInfoReasonKey : [NSString stringWithFormat:@"无效的预加载请求: URL=%@", mURL]
                    }]];
                    return;
                }
                [mCurReader prepare];
            }
                break;
            case HLSPrefetcherStatePreparing:
            case HLSPrefetcherStatePrefetching:
            case HLSPrefetcherStateCompleted:
                break;
        }
    }
}

- (void)cancel {
    @synchronized (self) {
        switch (mState) {
            case HLSPrefetcherStateUnknown:
            case HLSPrefetcherStatePreparing:
            case HLSPrefetcherStatePrefetching: {
                mState = HLSPrefetcherStateCompleted;
                if ( mCurReader != nil ) [mCurReader abortWithError:nil];
                if ( mAssociatedAssetPrefechers != nil ) [mAssociatedAssetPrefechers makeObjectsPerformSelector:@selector(cancel)];
                [self _notifyComplete:[NSError mcs_errorWithCode:MCSCancelledError userInfo:@{
                    MCSErrorUserInfoObjectKey : self,
                    MCSErrorUserInfoReasonKey : @"预加载被取消了"
                }]];
            }
                break;
            case HLSPrefetcherStateCompleted:
                break;
        }
    }
}

#pragma mark - MCSAssetReaderDelegate

- (void)reader:(id<MCSAssetReader>)reader didReceiveResponse:(id<MCSResponse>)response { }

- (void)reader:(id<MCSAssetReader>)reader hasAvailableDataWithLength:(NSUInteger)length {
    @synchronized (self) {
        switch (mState) {
            case HLSPrefetcherStateUnknown:
            case HLSPrefetcherStateCompleted:
                break; // break;
            case HLSPrefetcherStatePreparing:
                mState = HLSPrefetcherStatePrefetching; // fallThrough;
            case HLSPrefetcherStatePrefetching: {
                if ( [reader seekToOffset:reader.offset + length] ) {
                    // playlist, aes keys, subtitles 的加载不算到进度中;
                    switch ( reader.contentDataType ) {
                        case MCSDataTypeHLSPlaylist:
                        case MCSDataTypeHLSAESKey:
                        case MCSDataTypeHLSSubtitles:
                        case MCSDataTypeHLSInit:
                            break;
                        case MCSDataTypeHLSSegment: {
                            float progress = mProgress;
                            // size mode: specified size
                            if ( mPrefetchSize != 0 ) {
                                mLength += length;
                                 progress = mLength * 1.0f / mPrefetchSize;
                            }
                            // num mode: specified num of segment files
                            else {
                                HLSAsset *hls = reader.asset;
                                NSInteger segmentsCount = mPrefetchFileCount != NSNotFound ? MIN(mPrefetchFileCount, hls.segmentsCount) : hls.segmentsCount;
                                float curProgress = reader.offset * 1.0f / reader.response.range.length;
                                progress = (mNextSegmentIndex + curProgress) * 1.0f / segmentsCount;
                            }
                            
                            MCSPrefetcherDebugLog(@"%@: <%p>.prefetch { progress: %f };\n", NSStringFromClass(self.class), self, progress);
                            mProgress = progress;
                            [mDelegate prefetcher:self progressDidChange:progress];
                        }
                            break;
                        case MCSDataTypeHLSMask:
                        case MCSDataTypeHLS:
                        case MCSDataTypeFILEMask:
                        case MCSDataTypeFILE:
                            break;
                    }
                    
                    // finished
                    if ( reader.status == MCSReaderStatusFinished ) {
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
            case HLSPrefetcherStateUnknown:
            case HLSPrefetcherStatePreparing:
            case HLSPrefetcherStatePrefetching: {
                mState = HLSPrefetcherStateCompleted;
                [self _notifyComplete:error];
            }
                break;
            case HLSPrefetcherStateCompleted:
                break;
        }
    }
}

#pragma mark - MCSPrefetcherDelegate: variant stream or rendition prefetcher

- (void)prefetcher:(id<MCSPrefetcher>)prefetcher progressDidChange:(float)progress {
    @synchronized (self) {
        switch (mState) {
            case HLSPrefetcherStateUnknown:
            case HLSPrefetcherStateCompleted:
            case HLSPrefetcherStatePreparing:
                break; // break;
            case HLSPrefetcherStatePrefetching: {
                NSInteger index = [mAssociatedAssetPrefechers indexOfObject:prefetcher];
                float progressAll = (index + progress) / mAssociatedAssetPrefechers.count;
                mProgress = progressAll;
                [mDelegate prefetcher:self progressDidChange:progressAll];
            }
                break;
        }
    }
}

- (void)prefetcher:(id<MCSPrefetcher>)prefetcher didCompleteWithError:(NSError *_Nullable)error {
    @synchronized (self) {
        switch (mState) {
            case HLSPrefetcherStateUnknown:
            case HLSPrefetcherStatePreparing:
            case HLSPrefetcherStateCompleted:
                break; // break;
            case HLSPrefetcherStatePrefetching: {
                if ( error != nil || prefetcher == mAssociatedAssetPrefechers.lastObject ) {
                    mState = HLSPrefetcherStateCompleted;
                    [self _notifyComplete:error];
                    return;
                }
                
                NSInteger nextIndex = [mAssociatedAssetPrefechers indexOfObject:prefetcher] + 1;
                [mAssociatedAssetPrefechers[nextIndex] prepare];
            }
                break;
        }
    }
}

#pragma mark - unlocked

- (void)_readDidFinish:(id<MCSAssetReader>)reader {
    HLSAsset *asset = reader.asset;
    // first reader
    // 判断接下来应该加载 keys and segments 还是加载 variant stream and renditions;
    BOOL isFirstReader = reader.contentDataType == MCSDataTypeHLSPlaylist;
    if ( isFirstReader ) {
        id<HLSVariantStream> _Nullable selectedVariantStream = asset.selectedVariantStream;
        // prefetch keys and segments
        if ( selectedVariantStream == nil ) {
            // nothing
        }
        // prefetch variant stream and renditions
        else {
            id<HLSRendition> _Nullable selectedAudioRendition = asset.selectedAudioRendition;
            id<HLSRendition> _Nullable selectedVideoRendition = asset.selectedVideoRendition;
            NSMutableArray<id<MCSPrefetcher>> *assPfc = NSMutableArray.array;
            // variant stream prefetcher
            [assPfc addObject:[HLSPrefetcher.alloc initWithURL:[MCSURL.shared restoreURLFromHLSProxyURI:selectedVariantStream.URI]
                                              prefetchFileCount:mPrefetchFileCount
                                                   prefetchSize:mPrefetchSize
                                                      delegate:self]];
            // rendition prefetchers
            if ( selectedAudioRendition != nil ) {
                [assPfc addObject:[HLSPrefetcher.alloc initWithURL:[MCSURL.shared restoreURLFromHLSProxyURI:selectedAudioRendition.URI]
                                                  prefetchFileCount:mPrefetchFileCount
                                                       prefetchSize:mPrefetchSize
                                                          delegate:self]];
            }
            if ( selectedVideoRendition != nil ) {
                [assPfc addObject:[HLSPrefetcher.alloc initWithURL:[MCSURL.shared restoreURLFromHLSProxyURI:selectedVideoRendition.URI]
                                                  prefetchFileCount:mPrefetchFileCount
                                                       prefetchSize:mPrefetchSize
                                                          delegate:self]];
            }
            mAssociatedAssetPrefechers = assPfc.copy;
        }
    }
    
    mAssociatedAssetPrefechers == nil ? [self _prefetchNextItem:reader] : [mAssociatedAssetPrefechers.firstObject prepare];
}

- (void)_prefetchNextItem:(id<MCSAssetReader>)reader {
    HLSAsset *asset = reader.asset;
    BOOL isFirstReader = reader.contentDataType == MCSDataTypeHLSPlaylist;
    // update next index
    if ( !isFirstReader ) {
        mNextItemIndex += 1;
        
        if ( reader.contentDataType == MCSDataTypeHLSSegment ) {
            mNextSegmentIndex += 1;
        }
    }

    // size mode: specified size
    if ( mPrefetchSize != 0 ) {
        if ( mLength >= mPrefetchSize ) {
            mState = HLSPrefetcherStateCompleted;
            [self _notifyComplete:nil];
            return;
        }
    }
    // num mode: specified num of segment files
    else {
        NSInteger segmentsCount = mPrefetchFileCount != NSNotFound ? MIN(mPrefetchFileCount, asset.segmentsCount) : asset.segmentsCount;
        if ( mNextSegmentIndex >= segmentsCount ) {
            mState = HLSPrefetcherStateCompleted;
            [self _notifyComplete:nil];
            return;
        }
    }
    
    // prefetch next item
    __kindof id<HLSItem> nextItem = [asset itemAtIndex:mNextItemIndex];
    NSURL *proxyURL = [MCSURL.shared generateProxyURLFromHLSProxyURI:nextItem.URI];
    NSDictionary<NSString *, NSString *> *_Nullable headers = nil;
    if ( [nextItem conformsToProtocol:@protocol(HLSSegment)] ) {
        id<HLSSegment> segment = nextItem;
        NSRange byteRange = segment.byteRange;
        if ( byteRange.location != NSNotFound ) {
            headers = @{ @"Range": [NSString stringWithFormat:@"bytes=%lu-%lu", byteRange.location, NSMaxRange(byteRange) - 1] };
        }
    }
    NSURLRequest *request = [NSURLRequest mcs_requestWithURL:proxyURL headers:headers];
    mCurReader = [MCSAssetManager.shared readerWithRequest:request networkTaskPriority:0 delegate:self];
    [mCurReader prepare];
    
    MCSPrefetcherDebugLog(@"%@: <%p>.prepareFragment { index:%lu, segmentIndex: %lu, request: %@ };\n", NSStringFromClass(self.class), self, mNextItemIndex, mNextSegmentIndex, request);
}

/// unlocked
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
