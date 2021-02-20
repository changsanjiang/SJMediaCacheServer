//
//  HLSPrefetcher.m
//  CocoaAsyncSocket
//
//  Created by BlueDancer on 2020/6/11.
//

#import "HLSPrefetcher.h"
#import "MCSLogger.h"
#import "MCSAssetManager.h"
#import "NSURLRequest+MCS.h"  
#import "HLSAsset.h"
#import "HLSContentTSReader.h"
#import "HLSContentIndexReader.h"
#import "MCSQueue.h"

static dispatch_queue_t mcs_queue;

@interface HLSPrefetcher ()<MCSAssetReaderDelegate> {
    id<MCSAssetReader>_Nullable _reader;
    id<HLSURIItem> _Nullable _cur;
    NSUInteger _TsLoadedLength;
    NSUInteger _TsIndex;
    NSUInteger _fragmentIndex;
    float _progress;
    NSURL *_URL;
    NSUInteger _preloadSize;
    NSUInteger _numberOfPreloadedFiles;
    BOOL _isCalledPrepare;
    BOOL _isClosed;
    BOOL _isDone;
}
@end

@implementation HLSPrefetcher
@synthesize delegate = _delegate;
@synthesize delegateQueue = _delegateQueue;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mcs_queue = dispatch_queue_create("queue.HLSPrefetcher", DISPATCH_QUEUE_CONCURRENT);
    });
}

- (instancetype)initWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes delegate:(nullable id<MCSPrefetcherDelegate>)delegate delegateQueue:(nonnull dispatch_queue_t)delegateQueue {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _preloadSize = bytes;
        _delegate = delegate;
        _delegateQueue = delegateQueue;
        _fragmentIndex = NSNotFound;
        _TsIndex = NSNotFound;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)URL numberOfPreloadedFiles:(NSUInteger)num delegate:(nullable id<MCSPrefetcherDelegate>)delegate delegateQueue:(dispatch_queue_t)delegateQueue {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _numberOfPreloadedFiles = num;
        _delegate = delegate;
        _delegateQueue = delegateQueue;
        _fragmentIndex = NSNotFound;
        _TsIndex = NSNotFound;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)URL delegate:(nullable id<MCSPrefetcherDelegate>)delegate delegateQueue:(dispatch_queue_t)delegateQueue {
    return [self initWithURL:URL numberOfPreloadedFiles:NSUIntegerMax delegate:delegate delegateQueue:delegateQueue];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { preloadSize: %lu, numberOfPreloadedFiles: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)_preloadSize, (unsigned long)_numberOfPreloadedFiles];
}

- (void)dealloc {
    MCSPrefetcherDebugLog(@"%@: <%p>.dealloc;\n", NSStringFromClass(self.class), self);
}

- (void)prepare {
    dispatch_barrier_sync(mcs_queue, ^{
        if ( _isClosed || _isCalledPrepare )
            return;

        MCSPrefetcherDebugLog(@"%@: <%p>.prepare { preloadSize: %lu, numberOfPreloadedFiles: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)_preloadSize, (unsigned long)_numberOfPreloadedFiles);
        
        _isCalledPrepare = YES;

        NSURL *proxyURL = [MCSURL.shared proxyURLWithURL:_URL];
        NSURLRequest *proxyRequest = [NSURLRequest.alloc initWithURL:proxyURL];
        _reader = [MCSAssetManager.shared readerWithRequest:proxyRequest networkTaskPriority:0 delegate:self];
        [_reader prepare];
    });
}

- (void)close {
    dispatch_barrier_sync(mcs_queue, ^{
        [self _close];
    });
}

- (float)progress {
    __block float progress = 0;
    dispatch_sync(mcs_queue, ^{
        progress = _progress;
    });
    return progress;
}

- (BOOL)isClosed {
    __block BOOL isClosed = NO;
    dispatch_sync(mcs_queue, ^{
        isClosed = _isClosed;
    });
    return isClosed;
}

- (BOOL)isDone {
    __block BOOL isDone = NO;
    dispatch_sync(mcs_queue, ^{
        isDone = _isDone;
    });
    return isDone;
}

#pragma mark - MCSAssetReaderDelegate

- (void)reader:(id<MCSAssetReader>)reader prepareDidFinish:(id<MCSResponse>)response {
    /* nothing */
}

- (void)reader:(id<MCSAssetReader>)reader hasAvailableDataWithLength:(NSUInteger)length {
    dispatch_barrier_sync(mcs_queue, ^{
        if ( _isClosed ) {
            [reader close];
            return;
        }
        
        if ( [reader seekToOffset:reader.offset + length] ) {
            HLSAsset *asset = reader.asset;
            CGFloat progress = 0;
            
            // `Ts reader`
            if ( _cur.type == MCSDataTypeHLSTs ) {
                _TsLoadedLength += length;

                NSInteger totalLength = reader.response.range.length;
                // size mode
                if ( _preloadSize != 0 ) {
                    NSUInteger all = (_TsIndex == 0 && totalLength > _preloadSize) ? totalLength : _preloadSize;
                    progress = _TsLoadedLength * 1.0 / all;
                }
                // num mode
                else {
                    CGFloat curProgress = (reader.offset - reader.response.range.location) * 1.0 / totalLength;
                    NSUInteger all = asset.tsCount > _numberOfPreloadedFiles ? _numberOfPreloadedFiles : asset.tsCount;
                    progress = (_TsIndex + curProgress) / all;
                }
    
                if ( progress >= 1 ) progress = 1;
                _progress = progress;
                
                MCSPrefetcherDebugLog(@"%@: <%p>.preload { progress: %f };\n", NSStringFromClass(self.class), self, _progress);
            }
            
            if ( _delegate != nil ) {
                dispatch_async(_delegateQueue, ^{
                    [self.delegate prefetcher:self progressDidChange:progress];
                });
            }
            
            if ( reader.isReadingEndOfData ) {
                _progress == 1 ? [self _didCompleteWithError:nil] : [self _prepareNextFragment];
            }
        }
    });
}
  
- (void)reader:(id<MCSAssetReader>)reader anErrorOccurred:(NSError *)error {
    dispatch_barrier_sync(mcs_queue, ^{
        [self _didCompleteWithError:error];
    });
}

#pragma mark -

- (void)_prepareNextFragment {
    NSUInteger nextIndex = NSNotFound;
    id<HLSURIItem> item = nil;
    while ( YES ) {
        nextIndex = _fragmentIndex == NSNotFound ? 0 : _fragmentIndex + 1;
        HLSAsset *asset = _reader.asset;
        HLSParser *parser = asset.parser;
        item = [parser itemAtIndex:nextIndex];
        if ( item.type == MCSDataTypeHLSPlaylist && !item.isVariantStream )
            continue;
        break;
    }
    
    // loaded all items
    if ( item == nil ) {
        _progress = 1.0;
        [self _didCompleteWithError:nil];
        return;
    }
    
    if ( item.type == MCSDataTypeHLSTs )
        _TsIndex = _TsIndex != NSNotFound ? _TsIndex + 1 : 0;
    _fragmentIndex = nextIndex;
    _cur = item;
    
    NSURL *proxyURL = [MCSURL.shared HLS_proxyURLWithProxyURI:item.URI];
    NSURLRequest *request = [NSURLRequest mcs_requestWithURL:proxyURL headers:item.HTTPAdditionalHeaders];
    _reader = [MCSAssetManager.shared readerWithRequest:request networkTaskPriority:0 delegate:self];
    [_reader prepare];
    
    MCSPrefetcherDebugLog(@"%@: <%p>.prepareFragment { index:%lu, TsIndex: %lu, request: %@ };\n", NSStringFromClass(self.class), self, (unsigned long)_fragmentIndex, _TsIndex, request);
}

- (void)_didCompleteWithError:(nullable NSError *)error {
    if ( _isClosed )
        return;
    
    _isDone = (error == nil);
    
#ifdef DEBUG
    if ( _isDone )
        MCSPrefetcherDebugLog(@"%@: <%p>.done;\n", NSStringFromClass(self.class), self);
    else
        MCSPrefetcherErrorLog(@"%@:  <%p>.error { error: %@ };\n", NSStringFromClass(self.class), self, error);
#endif
    
    [self _close];
    
    if ( _delegate != nil ) {
        dispatch_async(_delegateQueue, ^{
            [self.delegate prefetcher:self didCompleteWithError:error];
        });
    }
}

- (void)_close {
    if ( _isClosed )
        return;
    
    [_reader close];
    
    _isClosed = YES;

    MCSPrefetcherDebugLog(@"%@: <%p>.close;\n", NSStringFromClass(self.class), self);
}
@end
