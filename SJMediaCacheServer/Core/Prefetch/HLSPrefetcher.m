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
#import "MCSUtils.h"
#import "MCSError.h"

@interface HLSURIItemProvider : NSObject
@property (nonatomic, weak, nullable) HLSAsset *asset;
@property (nonatomic, readonly, nullable) id<HLSURIItem> next;
@property (nonatomic, readonly) NSUInteger curTsIndex;
@property (nonatomic, readonly) NSUInteger curFragmentIndex;
- (BOOL)isVariantItem:(id<HLSURIItem>)item;
- (nullable NSArray<id<HLSURIItem>> *)renditionsItemsForVariantItem:(id<HLSURIItem>)item;
@end

@implementation HLSURIItemProvider

- (void)dealloc {
    [_asset readwriteRelease];
}

- (void)setAsset:(nullable HLSAsset *)asset {
    if ( asset != _asset ) {
        [asset readwriteRetain];
        [_asset readwriteRelease];
        
        _asset = asset;
        _curFragmentIndex = NSNotFound;
        _curTsIndex = NSNotFound;
    }
}

- (nullable id<HLSURIItem>)next {
    if ( _asset == nil )
        return nil;

    NSUInteger nextIndex = NSNotFound;
    id<HLSURIItem> item = nil;
    HLSAssetParser *parser = _asset.parser;
    while ( YES ) {
        nextIndex = (_curFragmentIndex == NSNotFound) ? 0 : (_curFragmentIndex + 1);
        item = [parser itemAtIndex:nextIndex];
        if ( item.type == MCSDataTypeHLSPlaylist && ![parser isVariantItem:item] )
            continue;
        if ( item.type == MCSDataTypeHLSSegment )
            _curTsIndex = (_curTsIndex == NSNotFound) ? 0 : (_curTsIndex + 1);
        _curFragmentIndex = nextIndex;
        break;
    }
    return item;
}

- (BOOL)isVariantItem:(id<HLSURIItem>)item {
    return [_asset.parser isVariantItem:item];
}

- (nullable NSArray<id<HLSURIItem>> *)renditionsItemsForVariantItem:(id<HLSURIItem>)item {
    return [_asset.parser renditionsItemsForVariantItem:item];
}
@end


#pragma mark - mark

@interface HLSRenditionsPrefetcher : NSObject<MCSPrefetcherDelegate>
- (instancetype)initWithURL:(NSURL *)URL numberOfPreloadedFiles:(NSUInteger)num progress:(void(^_Nullable)(float progress))progressBlock completed:(void(^_Nullable)(NSError *_Nullable error))completionBlock;
@property (nonatomic, readonly) float progress;
- (void)prepare;
- (void)cancel;
@end

@implementation HLSRenditionsPrefetcher {
    HLSPrefetcher *_prefetcher;
    void(^_Nullable _progressBlock)(float progress);
    void(^_Nullable _completionBlock)(NSError *_Nullable error);
}

- (instancetype)initWithURL:(NSURL *)URL numberOfPreloadedFiles:(NSUInteger)num progress:(void(^_Nullable)(float progress))progressBlock completed:(void(^_Nullable)(NSError *_Nullable error))completionBlock {
    self = [super init];
    if ( self ) {
        _progressBlock = progressBlock;
        _completionBlock = completionBlock;
        _prefetcher = [HLSPrefetcher.alloc initWithURL:URL numberOfPreloadedFiles:num delegate:self];
    }
    return self;
}

- (float)progress {
    return _prefetcher.progress;
}

- (void)prepare {
    [_prefetcher prepare];
}

- (void)cancel {
    [_prefetcher cancel];
}

#pragma mark - MCSPrefetcherDelegate

- (void)prefetcher:(id<MCSPrefetcher>)prefetcher progressDidChange:(float)progress {
    if ( _progressBlock != nil ) _progressBlock(progress);
}

- (void)prefetcher:(id<MCSPrefetcher>)prefetcher didCompleteWithError:(NSError *_Nullable)error {
    if ( _completionBlock != nil ) _completionBlock(error);
    if ( _progressBlock != nil ) _progressBlock = nil;
    if ( _completionBlock != nil ) _completionBlock = nil;
}
@end


#pragma mark - mark

@interface HLSPrefetcher ()<MCSAssetReaderDelegate> {
    id<MCSAssetReader>_Nullable _reader;
    id<HLSURIItem> _Nullable _cur;
    NSArray<id<HLSURIItem>> *_Nullable _renditionsItems;
    NSArray<HLSRenditionsPrefetcher *> *_Nullable _renditionsPrefetchers;
    HLSURIItemProvider *_itemProvider;
    NSUInteger _tsLoadedLength;
    NSUInteger _tsResponsedSize;
    float _tsProgress;
    float _renditionsProgress;
    NSURL *_URL;
    NSUInteger _preloadSize;
    NSUInteger _numberOfPreloadedFiles;
    BOOL _isCalledPrepare;
    BOOL _isCompleted;
}
@end


@implementation HLSPrefetcher
@synthesize delegate = _delegate;

- (instancetype)initWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes delegate:(nullable id<MCSPrefetcherDelegate>)delegate {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _preloadSize = bytes;
        _delegate = delegate;
        _itemProvider = HLSURIItemProvider.alloc.init;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)URL numberOfPreloadedFiles:(NSUInteger)num delegate:(nullable id<MCSPrefetcherDelegate>)delegate {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _numberOfPreloadedFiles = num;
        _delegate = delegate;
        _itemProvider = HLSURIItemProvider.alloc.init;
    }
    return self;
}

- (instancetype)initWithURL:(NSURL *)URL delegate:(nullable id<MCSPrefetcherDelegate>)delegate {
    return [self initWithURL:URL numberOfPreloadedFiles:NSNotFound delegate:delegate];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { preloadSize: %lu, numberOfPreloadedFiles: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)_preloadSize, (unsigned long)_numberOfPreloadedFiles];
}

- (void)dealloc {
    MCSPrefetcherDebugLog(@"%@: <%p>.dealloc;\n", NSStringFromClass(self.class), self);
}

- (void)prepare {
    @synchronized (self) {
        if ( _isCompleted || _isCalledPrepare )
            return;

        MCSPrefetcherDebugLog(@"%@: <%p>.prepare { preloadSize: %lu, numberOfPreloadedFiles: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)_preloadSize, (unsigned long)_numberOfPreloadedFiles);
        
        _isCalledPrepare = YES;

        NSURL *proxyURL = [MCSURL.shared generateProxyURLFromURL:_URL];
        NSURLRequest *proxyRequest = [NSURLRequest.alloc initWithURL:proxyURL];
        _reader = [MCSAssetManager.shared readerWithRequest:proxyRequest networkTaskPriority:0 delegate:self];
        [_reader prepare];
    }
}

- (void)cancel {
    @synchronized (self) {
        [self _cancel];
    }
}

- (float)progress {
    @synchronized (self) {
        float progress = (_tsProgress + _renditionsProgress) / (1 + (_renditionsItems.count != 0 ? 1 : 0));
        return progress;
    }
}
 
#pragma mark - MCSAssetReaderDelegate

- (void)reader:(id<MCSAssetReader>)reader didReceiveResponse:(id<MCSResponse>)response {
    @synchronized (self) {
        if ( _cur.type == MCSDataTypeHLSSegment ) {
            _tsResponsedSize += response.range.length;
        }
    }
}

- (void)reader:(id<MCSAssetReader>)reader hasAvailableDataWithLength:(NSUInteger)length {
    @synchronized (self) {
        if ( _isCompleted ) return;
        
        if ( [reader seekToOffset:reader.offset + length] ) {
            HLSAsset *asset = reader.asset;
            CGFloat progress = 0;
            
            // `Ts reader`
            if ( _cur.type == MCSDataTypeHLSSegment ) {
                _tsLoadedLength += length;

                NSInteger totalLength = reader.response.range.length;
                // size mode
                if ( _preloadSize != 0 ) {
                    NSUInteger all = _preloadSize > _tsResponsedSize ? _preloadSize : _tsResponsedSize;
                    progress = _tsLoadedLength * 1.0 / all;
                }
                // num mode
                else {
                    CGFloat curProgress = (reader.offset - reader.response.range.location) * 1.0 / totalLength;
                    NSUInteger all = asset.tsCount > _numberOfPreloadedFiles ? _numberOfPreloadedFiles : asset.tsCount;
                    progress = (_itemProvider.curTsIndex + curProgress) / all;
                }

                if ( progress > 1 ) progress = 1;
                _tsProgress = progress;
            }
            
            if ( _delegate != nil ) {
                float progress = (_tsProgress + _renditionsProgress) / (1 + (_renditionsItems.count != 0 ? 1 : 0));
                MCSPrefetcherDebugLog(@"%@: <%p>.preload { progress: %f };\n", NSStringFromClass(self.class), self, progress);

                [_delegate prefetcher:self progressDidChange:progress];
            }
            
            if ( reader.status == MCSReaderStatusFinished ) {
                _tsProgress == 1 ? [self _prefetchRenditionsItems] : [self _prepareNextFragment];
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

#pragma mark -

- (void)_prepareNextFragment {
    // update asset
    _itemProvider.asset = _reader.asset;
    
    // next item
    _cur = _itemProvider.next;
    
    // All items loaded
    if ( _cur == nil ) {
        _tsProgress = 1.0;
        [self _prefetchRenditionsItems];
        return;
    }
    
    if ( [_itemProvider isVariantItem:_cur] ) {
        _renditionsItems = [_itemProvider renditionsItemsForVariantItem:_cur];
    }
    
    // prepare for reader
    NSURL *proxyURL = [MCSURL.shared HLS_proxyURLWithProxyURI:_cur.URI];
    NSURLRequest *request = [NSURLRequest mcs_requestWithURL:proxyURL headers:_cur.HTTPAdditionalHeaders];
    _reader = [MCSAssetManager.shared readerWithRequest:request networkTaskPriority:0 delegate:self];
    [_reader prepare];
    
    MCSPrefetcherDebugLog(@"%@: <%p>.prepareFragment { index:%lu, TsIndex: %lu, request: %@ };\n", NSStringFromClass(self.class), self, (unsigned long)_itemProvider.curFragmentIndex, _itemProvider.curTsIndex, request);
}

- (void)_prefetchRenditionsItems {
    if ( _renditionsItems.count == 0 ) {
        [self _completeWithError:nil];
        return;
    }
    
    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<HLSRenditionsPrefetcher *> *prefetchers = [NSMutableArray arrayWithCapacity:_renditionsItems.count];
    _renditionsPrefetchers = prefetchers;
    __block NSError *error = nil;
    for ( id<HLSURIItem> item in _renditionsItems ) {
        dispatch_group_enter(group);
        NSURL *URL = [MCSURL.shared HLS_URLWithProxyURI:item.URI];
        HLSRenditionsPrefetcher *prefetcher = [HLSRenditionsPrefetcher.alloc initWithURL:URL numberOfPreloadedFiles:_itemProvider.curTsIndex + 1 progress:^(float progress) {
            float allProgress = 0;
            for ( HLSRenditionsPrefetcher *prefetcher in prefetchers ) {
                allProgress += prefetcher.progress;
            }
            @synchronized (self) {
                [self _updateRenditionsProgress:allProgress];
            }
        } completed:^(NSError * _Nullable err) {
            if ( err != nil && error == nil ) {
                error = err;
                for ( HLSRenditionsPrefetcher *cur in prefetchers ) {
                    [cur cancel];
                }
            }
            dispatch_group_leave(group);
        }];
        [prefetcher prepare];
        [prefetchers addObject:prefetcher];
    }
    
    dispatch_group_notify(group, dispatch_get_global_queue(0, 0), ^{
        @synchronized (self) {
            [self _completeWithError:error];
        }
    });
}

#pragma mark - unlocked

/// unlocked
- (void)_updateRenditionsProgress:(float)allRenditionsProgress {
    if ( !_isCompleted ) {
        _renditionsProgress = allRenditionsProgress;
        
        float progress = (_tsProgress + _renditionsProgress) / (1 + (_renditionsItems.count != 0 ? 1 : 0));
        MCSPrefetcherDebugLog(@"%@: <%p>.preload { progress: %f };\n", NSStringFromClass(self.class), self, progress);
        
        if ( _delegate != nil ) {
            [_delegate prefetcher:self progressDidChange:progress];
        }
    }
}

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
        
        [_renditionsPrefetchers makeObjectsPerformSelector:@selector(close)];
        _renditionsPrefetchers = nil;
        
        MCSPrefetcherDebugLog(@"%@: <%p>.close;\n", NSStringFromClass(self.class), self);
        
        if ( _delegate != nil ) {
            [_delegate prefetcher:self didCompleteWithError:error];
        }
    }
}
@end
