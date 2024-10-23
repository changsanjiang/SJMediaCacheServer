//
//  HLSAsset.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "HLSAsset.h"
#import "MCSConfiguration.h"
#import "MCSURL.h"
#import "MCSUtils.h"
#import "MCSConsts.h"
#import "HLSAssetContentProvider.h"
#import "HLSAssetReader.h"
#import "MCSRootDirectory.h"
#import "MCSRequest.h"
#import "MCSAssetContent.h"
#import "NSFileManager+MCS.h"
#import "MCSMimeType.h"
#import "HLSAssetSegmentNode.h"
#import "MCSAssetManager.h"

static NSString *HLS_AES_KEY_MIME_TYPE = @"application/octet-stream";

@interface HLSAsset () {
    NSHashTable<id<MCSAssetObserver>> *mObservers;
    HLSAssetParser *_Nullable mParser;
    MCSConfiguration *mConfiguration;
    HLSAssetContentProvider *mProvider;
    id<MCSAssetContent> _Nullable mPlaylistContent;
    NSMutableDictionary<NSString *, id<MCSAssetContent>> * _Nullable mAESKeys; // { identifier: content }
    NSMutableDictionary<NSString *, id<MCSAssetContent>> * _Nullable mInitializations; // { identifier: content }
    NSMutableDictionary<NSString *, id<HLSItem>> *_Nullable mSegments; // { nodeIdentifier: item }
    HLSAssetSegmentNodeMap *mSegmentNodeMap; // ts
    
    HLSAsset *_Nullable mVariantStreamAsset;
    HLSAsset *_Nullable mAudioRenditionAsset;
    HLSAsset *_Nullable mVideoRenditionAsset;
    id<MCSAssetContent> _Nullable mSubtitlesContent;
    
    __weak HLSAsset *_Nullable mMasterAsset;
    BOOL mPrepared;
    BOOL mAssembled; // 是否已组合完成, 是否已得到完整内容; 虽然得到了完整内容, 但是文件夹下可能还存在正在读取的冗余数据;
    BOOL mFullyTrimmed; // 所有冗余数据都已删除;
}

@property (nonatomic) NSInteger id; // saveable
@property (nonatomic, copy) NSString *name; // saveable
@end

@implementation HLSAsset
@synthesize id = _id;

+ (NSString *)sql_primaryKey {
    return @"id";
}

+ (NSArray<NSString *> *)sql_autoincrementlist {
    return @[@"id"];
}

+ (NSArray<NSString *> *)sql_blacklist {
    return @[@"readwriteCount", @"isStored", @"configuration", @"contents", @"parser"];
}

- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    _name = name.copy;
    return self;
}

- (void)dealloc {
    [mObservers removeAllObjects];
}

- (void)prepare {
    @synchronized (self) {
        NSParameterAssert(self.name != nil);
        if ( mPrepared )
            return;
        mPrepared = YES;
        mConfiguration = MCSConfiguration.alloc.init;
        NSString *directory = [MCSRootDirectory assetPathForFilename:self.name];
        mProvider = [HLSAssetContentProvider.alloc initWithDirectory:directory];
        mSegmentNodeMap = [HLSAssetSegmentNodeMap.alloc init];

        // find proxy playlist file
        NSString *proxyPlaylistFilePath = [mProvider loadPlaylistFilePath];
        if ( proxyPlaylistFilePath != nil ) {
            NSError *error = nil;
            mParser = [HLSAssetParser.alloc initWithProxyPlaylist:[NSString stringWithContentsOfFile:proxyPlaylistFilePath encoding:NSUTF8StringEncoding error:&error]];
            if ( mParser != nil ) [self _onPlaylist:proxyPlaylistFilePath];
        }
    }
}

- (id<MCSConfiguration>)configuration {
    return mConfiguration;
}

- (NSString *)path {
    return [MCSRootDirectory assetPathForFilename:_name];
}

- (NSUInteger)allItemsCount {
    @synchronized (self) {
        return mParser != nil ? mParser.allItemsCount : 0;
    }
}

- (NSUInteger)segmentsCount {
    @synchronized (self) {
        return mParser != nil ? mParser.segmentsCount : 0;
    }
}

- (nullable __kindof id<HLSItem>)itemAtIndex:(NSUInteger)index {
    @synchronized (self) {
        if ( mParser != nil ) {
            if ( index < mParser.allItemsCount ) {
                return mParser.allItems[index];
            }
        }
        return nil;
    }
}

- (float)completeness {
    @synchronized (self) {
        if ( mAssembled ) return 1;
        if ( mParser == nil ) return 0;
        if ( mVariantStreamAsset == nil ) {
            if ( mParser.segmentsCount == 0 ) {
                return 1;
            }

            __block float progressAll = 0;
            NSUInteger itemsCount = 0;
            
            // ignore keys
//            // keys progress
//            NSArray<id<HLSKey>> *keys = mParser.keys;
//            if ( keys.count != 0 ) {
//                itemsCount += keys.count;
//                progressAll += mAESKeyContents.count;
//            }
            
            // segments progress
            itemsCount += mParser.segmentsCount;
            [mSegmentNodeMap enumerateNodesUsingBlock:^(HLSAssetSegmentNode * _Nonnull node, BOOL * _Nonnull stop) {
                id<HLSAssetSegment> longestContent = node.longestContent;
                progressAll += longestContent.length * 1.0f / longestContent.byteRange.length;
            }];
            return progressAll / itemsCount;
        }
        else {
            float progressAll = mVariantStreamAsset.completeness;
            NSUInteger itemsCount = 1;
            if ( mAudioRenditionAsset != nil ) {
                itemsCount += 1;
                progressAll += mAudioRenditionAsset.completeness;
            }
            if ( mVideoRenditionAsset != nil ) {
                itemsCount += 1;
                progressAll += mVideoRenditionAsset.completeness;
            }
            if ( mParser.subtitlesRendition != nil ) {
                itemsCount += 1;
                progressAll += mSubtitlesContent != nil ? 1 : 0;
            }
            return progressAll / itemsCount;
        }
    }
}
#pragma mark - VariantStream

- (nullable HLSAsset *)selectedVariantStreamAsset {
    @synchronized (self) {
        return mVariantStreamAsset;
    }
}

- (nullable HLSAsset *)selectedAudioRenditionAsset {
    @synchronized (self) {
        return mAudioRenditionAsset;
    }
}

- (nullable HLSAsset *)selectedVideoRenditionAsset {
    @synchronized (self) {
        return mVideoRenditionAsset;
    }
}

- (nullable HLSAsset *)masterAsset {
    @synchronized (self) {
        return mMasterAsset;
    }
}

- (nullable id<HLSVariantStream>)selectedVariantStream {
    @synchronized (self) {
        return mParser != nil ? mParser.variantStream : nil;
    }
}

- (nullable id<HLSRendition>)selectedAudioRendition {
    @synchronized (self) {
        return mParser != nil ? mParser.audioRendition : nil;
    }
}

- (nullable id<HLSRendition>)selectedVideoRendition {
    @synchronized (self) {
        return mParser != nil ? mParser.videoRendition : nil;
    }
}

- (nullable id<HLSRendition>)selectedSubtitlesRendition {
    @synchronized (self) {
        return mParser != nil ? mParser.subtitlesRendition : nil;
    }
}

#pragma mark - mark

- (NSString *)generateAESKeyIdentifierWithOriginalURL:(NSURL *)originalURL {
    return [MCSURL.shared generateProxyIdentifierFromHLSOriginalURL:originalURL extension:HLS_EXTENSION_KEY];
}

- (NSString *)generateSubtitlesIdentifierWithOriginalURL:(NSURL *)originalURL {
    return [MCSURL.shared generateProxyIdentifierFromHLSOriginalURL:originalURL extension:HLS_EXTENSION_SUBTITLES];
}

- (NSString *)generateInitializationIdentifierWithOriginalURL:(NSURL *)originalURL {
    return [MCSURL.shared generateProxyIdentifierFromHLSOriginalURL:originalURL extension:HLS_EXTENSION_INIT];
}

- (NSString *)generateSegmentIdentifierWithOriginalURL:(NSURL *)originalURL {
    return [MCSURL.shared generateProxyIdentifierFromHLSOriginalURL:originalURL extension:HLS_EXTENSION_SEGMENT];
}

/// @param byteRange #EXT-X-BYTERANGE or { NSNotFound, NSNotFound }
- (NSString *)generateSegmentNodeIdentifierWithSegmentIdentifier:(NSString *)segmentIdentifier requestHeaderByteRange:(NSRange)byteRange {
    return byteRange.location == NSNotFound ? segmentIdentifier : [NSString stringWithFormat:@"%@_%lu_%lu", segmentIdentifier, byteRange.location, byteRange.length];
}

#pragma mark - mark

- (MCSAssetType)type {
    return MCSAssetTypeHLS;
}


- (BOOL)isStored {
    @synchronized (self) {
        if ( !mAssembled ) {
            [self _check];
        }
        return mAssembled;
    }
}

- (nullable id<MCSAssetReader>)readerWithRequest:(id<MCSRequest>)request networkTaskPriority:(float)networkTaskPriority readDataDecryptor:(NSData *(^_Nullable)(NSURLRequest *request, NSUInteger offset, NSData *data))readDataDecryptor delegate:(nullable id<MCSAssetReaderDelegate>)delegate {
    return [HLSAssetReader.alloc initWithAsset:self request:request networkTaskPriority:networkTaskPriority readDataDecryptor:readDataDecryptor delegate:delegate];
}

- (nullable id<MCSAssetContent>)getPlaylistContent {
    @synchronized (self) {
        return mPlaylistContent != nil ? [mPlaylistContent readwriteRetain] : nil;
    }
}

- (nullable id<MCSAssetContent>)createPlaylistContentWithOriginalURL:(NSURL *)originalURL currentURL:(NSURL *)currentURL playlist:(NSData *)rawData error:(out NSError **)errorPtr {
    @synchronized (self) {
        if ( mPlaylistContent == nil ) {
            NSError *error = nil;
            NSString *proxyPlaylist = [HLSAssetParser proxyPlaylistWithAsset:self.name originalURL:originalURL currentURL:currentURL playlist:rawData variantStreamSelectionHandler:_variantStreamSelectionHandler renditionSelectionHandler:_renditionSelectionHandler error:&error];
            if ( proxyPlaylist != nil ) {
                NSString *filePath = [mProvider writeContentsToPlaylist:proxyPlaylist error:&error];
                if ( filePath != nil ) {
                    mParser = [HLSAssetParser.alloc initWithProxyPlaylist:proxyPlaylist];
                    if ( mParser != nil ) [self _onPlaylist:filePath];
                }
            }
            if ( error != nil && errorPtr != NULL ) *errorPtr = error;
        }
        return mPlaylistContent != nil ? [mPlaylistContent readwriteRetain] : nil;
    }
}

- (nullable id<MCSAssetContent>)getAESKeyContentWithOriginalURL:(NSURL *)originalURL {
    @synchronized (self) {
        NSString *identifier = [self generateAESKeyIdentifierWithOriginalURL:originalURL];
        id<MCSAssetContent> _Nullable content = mAESKeys != nil ? mAESKeys[identifier] : nil;
        return content != nil ? [content readwriteRetain] : nil;
    }
}

- (nullable id<MCSAssetContent>)createAESKeyContentWithOriginalURL:(NSURL *)originalURL data:(NSData *)data error:(out NSError **)errorPtr {
    @synchronized (self) {
        NSString *identifier = [self generateAESKeyIdentifierWithOriginalURL:originalURL];
        id<MCSAssetContent> _Nullable content = mAESKeys != nil ? mAESKeys[identifier] : nil;
        NSError *error = nil;
        if ( content == nil ) {
            NSString *filePath = [mProvider writeDataToAESKey:data forIdentifier:identifier error:&error];
            if ( filePath != nil ) {
                content = [MCSAssetContent.alloc initWithMimeType:HLS_AES_KEY_MIME_TYPE filePath:filePath position:0 length:data.length];
                if ( mAESKeys == nil ) mAESKeys = NSMutableDictionary.dictionary;
                mAESKeys[identifier] = content;
            }
            if ( error != nil && errorPtr != NULL ) *errorPtr = error;
        }
        return content != nil ? [content readwriteRetain] : nil;
    }
}

- (nullable id<MCSAssetContent>)getInitializationContentWithOriginalURL:(NSURL *)originalURL byteRange:(NSRange)byteRange {
#warning next ...
}
- (nullable id<MCSAssetContent>)createInitializationContentWithOriginalURL:(NSURL *)originalURL byteRange:(NSRange)byteRange data:(NSData *)data error:(out NSError **)error {
    
}


- (nullable id<MCSAssetContent>)getSubtitlesContentWithOriginalURL:(NSURL *)originalURL {
    @synchronized (self) {
// subtitles only one can be selected;
//        NSString *identifier = [self generateSubtitlesIdentifierWithOriginalURL:originalURL];
//        id<MCSAssetContent> _Nullable content = mSubtitlesContents != nil ? mSubtitlesContents[identifier] : nil;
//        return content != nil ? [content readwriteRetain] : nil;
        return mSubtitlesContent != nil ? [mSubtitlesContent readwriteRetain] : nil;
    }
}

- (nullable id<MCSAssetContent>)createSubtitlesContentWithOriginalURL:(NSURL *)originalURL data:(NSData *)data error:(out NSError **)errorPtr {
    @synchronized (self) {
        if ( mSubtitlesContent == nil ) {
            NSString *identifier = [self generateSubtitlesIdentifierWithOriginalURL:originalURL];
            NSError *error = nil;
            NSString *filePath = [mProvider writeDataToSubtitles:data forIdentifier:identifier error:&error];
            if ( filePath != nil ) {
                mSubtitlesContent = [MCSAssetContent.alloc initWithMimeType:MCSMimeType(originalURL.path.pathExtension) filePath:filePath position:0 length:data.length];
            }
            if ( error != nil && errorPtr != NULL ) *errorPtr = error;
        }
        return mSubtitlesContent != nil ? [mSubtitlesContent readwriteRetain] : nil;
    }
}


/// 将返回如下两种content, 如果未满足条件, 则返回nil
///
///     - 如果ts已缓存完毕, 则返回完整的content
///
///     - 如果ts被缓存了一部分(可能存在多个), 则将返回长度最长的并且readwrite为0的content
///
/// 该操作将会对 content 进行一次 readwriteRetain, 请在不需要时, 调用一次 readwriteRelease.
- (id<HLSAssetSegment>)getSegmentContentWithOriginalURL:(NSURL *)originalURL byteRange:(NSRange)byteRange {
    @synchronized (self) {
        NSString *segmentIdentifier = [self generateSegmentIdentifierWithOriginalURL:originalURL];
        NSString *nodeIdentifier = [self generateSegmentNodeIdentifierWithSegmentIdentifier:segmentIdentifier requestHeaderByteRange:byteRange];
        HLSAssetSegmentNode *node = [mSegmentNodeMap nodeForIdentifier:nodeIdentifier];
        if ( node != nil ) {
            id<HLSAssetSegment> segment = node.fullOrIdleContent;
            return segment != nil ? [segment readwriteRetain] : nil;
        }
        return nil;
    }
}

- (nullable id<MCSAssetContent>)createContentWithDataType:(MCSDataType)dataType response:(id<MCSDownloadResponse>)response error:(NSError *__autoreleasing  _Nullable * _Nullable)errorPtr {
    switch ( dataType ) {
        case MCSDataTypeHLSMask:
        case MCSDataTypeHLSPlaylist:
        case MCSDataTypeHLSAESKey:
        case MCSDataTypeHLSSubtitles:
        case MCSDataTypeHLSInit:
        case MCSDataTypeHLS:
        case MCSDataTypeFILEMask:
        case MCSDataTypeFILE: return nil; /* return nil; */
        case MCSDataTypeHLSSegment: { // only segment
            @synchronized (self) {
                id<HLSAssetSegment>content = nil;
                NSString *segmentIdentifier = [self generateSegmentIdentifierWithOriginalURL:response.originalRequest.URL];
                NSRange byteRange = MCSRequestRange(MCSRequestGetContentRange(response.originalRequest.allHTTPHeaderFields));
                NSString *nodeIdentifier = [self generateSegmentNodeIdentifierWithSegmentIdentifier:segmentIdentifier requestHeaderByteRange:byteRange];
                id<HLSItem> item = mSegments[nodeIdentifier];
                NSURL *originalURL = [MCSURL.shared restoreURLFromHLSProxyURI:item.URI];
                NSString *mimeType = MCSMimeType(originalURL.path.pathExtension);
                BOOL isSubrange = byteRange.length != NSNotFound;
                content = !isSubrange ? [mProvider createSegmentWithIdentifier:segmentIdentifier mimeType:mimeType totalLength:response.totalLength error:errorPtr] :
                                        [mProvider createSegmentWithIdentifier:segmentIdentifier mimeType:mimeType totalLength:response.totalLength byteRange:byteRange error:errorPtr];
                if ( content != nil ) {
                    [mSegmentNodeMap attachContentToNode:content identifier:nodeIdentifier];
                    return [content readwriteRetain];
                }
                return nil;
            }
        }
    }
}

- (void)clear {
    @synchronized (self) {
        for ( id<MCSAssetObserver> observer in MCSAllHashTableObjects(mObservers) ) {
            if ( [observer respondsToSelector:@selector(assetWillClear:)] ) {
                [observer assetWillClear:self];
            }
        }
        mAssembled = NO;
        mFullyTrimmed = NO;
        mParser = nil;
        mPlaylistContent = nil;
        mAESKeys = nil;
        mSegments = nil;
        [mSegmentNodeMap removeAllNodes];
        if ( mVariantStreamAsset != nil ) {
            [mVariantStreamAsset clear];
            mVariantStreamAsset = nil;
        }
        if ( mAudioRenditionAsset != nil ) {
            [mAudioRenditionAsset clear];
            mAudioRenditionAsset = nil;
        }
        if ( mVideoRenditionAsset != nil ) {
            [mVideoRenditionAsset clear];
            mVideoRenditionAsset = nil;
        }
        mSubtitlesContent = nil;
        [mProvider clear];
        
        for ( id<MCSAssetObserver> observer in MCSAllHashTableObjects(mObservers) ) {
            if ( [observer respondsToSelector:@selector(assetDidClear:)] ) {
                [observer assetDidClear:self];
            }
        }
    }
}

- (void)registerObserver:(id<MCSAssetObserver>)observer {
    if ( observer != nil ) {
        @synchronized (self) {
            if ( mObservers == nil ) {
                mObservers = NSHashTable.weakObjectsHashTable;
            }
            [mObservers addObject:observer];
        }
    }
}

- (void)removeObserver:(id<MCSAssetObserver>)observer {
    @synchronized (self) {
        [mObservers removeObject:observer];
    }
}

#pragma mark - readwrite

- (instancetype)readwriteRetain {
    @synchronized (self) {
        [super readwriteRetain];
        if ( mMasterAsset != nil ) [mMasterAsset readwriteRetain];
    }
    return self;
}

- (void)readwriteRelease {
    @synchronized (self) {
        [super readwriteRelease];
        if ( mMasterAsset != nil ) [mMasterAsset readwriteRelease];
        if ( !mAssembled ) [self _check];
        else if ( !mFullyTrimmed ) [self _trimRedundantSegmentContents];
    }
}

#ifdef DEBUG
- (void)readwriteCountDidChange:(NSInteger)count {
    if ( count == 0 ) {
        [mSegmentNodeMap enumerateNodesUsingBlock:^(HLSAssetSegmentNode * _Nonnull node, BOOL * _Nonnull stop) {
            for ( id<HLSAssetSegment> segment in node.contents ) {
                if ( segment.readwriteCount != 0 ) {
                    NSLog(@"Warning: content read/write count is not zero. Content: %@, Read/Write Count: %ld", segment, (long)segment.readwriteCount);
                }
            }
        }];
    }
}
#endif

#pragma mark - unlocked

- (void)_onPlaylist:(NSString *)proxyPlaylistFilePath {
    NSParameterAssert(mParser != nil);
    // playlist, aes key, subtitles 都属于小文件, 目录中只要存在对应文件就说明已下载完毕;

    // playlist content
    mPlaylistContent = [MCSAssetContent.alloc initWithFilePath:proxyPlaylistFilePath position:0 length:[NSFileManager.defaultManager mcs_fileSizeAtPath:proxyPlaylistFilePath]];
    // find existing aes contents
    [mParser.keys enumerateObjectsUsingBlock:^(id<HLSKey>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSURL *originalURL = [MCSURL.shared restoreURLFromHLSProxyURI:obj.URI];
        NSString *identifier = [self generateAESKeyIdentifierWithOriginalURL:originalURL];
        NSString *filePath = [mProvider loadAESKeyFilePathForIdentifier:identifier];
        if ( filePath != nil ) {
            if ( mAESKeys == nil ) mAESKeys = NSMutableDictionary.dictionary;
            mAESKeys[identifier] = [MCSAssetContent.alloc initWithMimeType:HLS_AES_KEY_MIME_TYPE filePath:filePath position:0 length:[NSFileManager.defaultManager mcs_fileSizeAtPath:filePath]];
        }
    }];
    
    if ( mParser.segmentsCount != 0 ) {
        mSegments = NSMutableDictionary.dictionary;
        [mParser.segments enumerateObjectsUsingBlock:^(id<HLSSegment>  _Nonnull item, NSUInteger idx, BOOL * _Nonnull stop) {
            NSURL *originalURL = [MCSURL.shared restoreURLFromHLSProxyURI:item.URI];
            NSString *segmentIdentifier = [self generateSegmentIdentifierWithOriginalURL:originalURL];
            NSRange byteRange = item.byteRange;
            NSString *nodeIdentifier = [self generateSegmentNodeIdentifierWithSegmentIdentifier:segmentIdentifier requestHeaderByteRange:byteRange];
            mSegments[nodeIdentifier] = item;
        }];
        
        // find existing segment contents
        NSArray<NSString *> *existingFilenames = [mProvider loadSegmentFilenames];
        if ( existingFilenames.count != 0 ) {
            [existingFilenames enumerateObjectsUsingBlock:^(NSString * _Nonnull filename, NSUInteger idx, BOOL * _Nonnull stop) {
                NSRange byteRange = { NSNotFound, NSNotFound };
                NSString *segmentIdentifier = [mProvider getSegmentIdentifierByFilename:filename byteRange:&byteRange];
                NSString *nodeIdentifier = [self generateSegmentNodeIdentifierWithSegmentIdentifier:segmentIdentifier requestHeaderByteRange:byteRange];
                id<HLSItem> item = mSegments[nodeIdentifier];
                NSURL *originalURL = [MCSURL.shared restoreURLFromHLSProxyURI:item.URI];
                NSString *mimeType = MCSMimeType(originalURL.path.pathExtension);
                id<HLSAssetSegment> content = [mProvider getSegmentByFilename:filename mimeType:mimeType];
                [mSegmentNodeMap attachContentToNode:content identifier:nodeIdentifier];
            }];
        }
    }
    else if ( mParser.variantStream != nil ) {
        //    __weak HLSAsset *_Nullable mVariantStreamAsset;
        //    __weak HLSAsset *_Nullable mAudioRenditionAsset;
        //    __weak HLSAsset *_Nullable mVideoRenditionAsset;
        //    id<MCSAssetContent> _Nullable mSubtitlesContent;
        
        id<HLSVariantStream> selectedVariantStream = mParser.variantStream;
        id<HLSRendition> _Nullable selectedAudioRendition = mParser.audioRendition;
        id<HLSRendition> _Nullable selectedVideoRendition = mParser.videoRendition;
        id<HLSRendition> _Nullable selectedSubtitlesRendition = mParser.subtitlesRendition;
        mVariantStreamAsset = [MCSAssetManager.shared assetWithURL:[MCSURL.shared restoreURLFromHLSProxyURI:selectedVariantStream.URI]];
        mVariantStreamAsset->mMasterAsset = self;
        [mVariantStreamAsset prepare];
        
        if ( selectedAudioRendition != nil ) {
            mAudioRenditionAsset = [MCSAssetManager.shared assetWithURL:[MCSURL.shared restoreURLFromHLSProxyURI:selectedAudioRendition.URI]];
            mAudioRenditionAsset->mMasterAsset = self;
            [mAudioRenditionAsset prepare];
        }
        
        if ( selectedVideoRendition != nil ) {
            mVideoRenditionAsset = [MCSAssetManager.shared assetWithURL:[MCSURL.shared restoreURLFromHLSProxyURI:selectedVideoRendition.URI]];
            mVideoRenditionAsset->mMasterAsset = self;
            [mVideoRenditionAsset prepare];
        }
        
        if ( selectedSubtitlesRendition != nil ) {
            NSURL *originalURL = [MCSURL.shared restoreURLFromHLSProxyURI:selectedSubtitlesRendition.URI];
            NSString *identifier = [self generateSubtitlesIdentifierWithOriginalURL:originalURL];
            NSString *filePath = [mProvider loadSubtitlesFilePathForIdentifier:identifier];
            // 同样都是小文件, 目录中只要存在对应文件就说明已下载完毕;
            if ( filePath != nil ) {
                mSubtitlesContent = [MCSAssetContent.alloc initWithMimeType:MCSMimeType(originalURL.path.pathExtension) filePath:filePath position:0 length:[NSFileManager.defaultManager mcs_fileSizeAtPath:filePath]];
            }
        }
    }
    // notify
    for ( id<MCSAssetObserver> observer in MCSAllHashTableObjects(mObservers) ) {
        if ( [observer respondsToSelector:@selector(assetDidLoadMetadata:)] ) {
            [observer assetDidLoadMetadata:self];
        }
    }
        
    // check
    [self _check];
}

/// unlocked
- (void)_trimRedundantSegmentContents {
    if ( !mFullyTrimmed ) {
        __block BOOL isFullyTrimmed = mParser != nil && mParser.segmentsCount == mSegmentNodeMap.count;
        [mSegmentNodeMap enumerateNodesUsingBlock:^(HLSAssetSegmentNode * _Nonnull node, BOOL * _Nonnull stop) {
            id<HLSAssetSegment> _Nullable fullSegment = node.fullContent;
            // trim redundant contents
            if ( fullSegment != nil && node.numberOfContents > 1 ) [self trimRedundantContentsForNode:node reservedContent:fullSegment];
            if ( isFullyTrimmed && node.numberOfContents > 1 ) isFullyTrimmed = NO;
        }];
        if ( isFullyTrimmed ) mFullyTrimmed = isFullyTrimmed;
    }
}

/// unlocked
///
/// update mStored and trim redundant contents
- (void)_check {
    if ( mAssembled || mParser == nil ) return;
    if      ( mParser.segmentsCount != 0 ) {
        if ( mAESKeys.count != mParser.keys.count ) return;
        if ( mSegmentNodeMap.count != mParser.segmentsCount ) return;
        __block BOOL isAllSegmentsCached = YES;
        __block BOOL isFullyTrimmed = YES;
        [mSegmentNodeMap enumerateNodesUsingBlock:^(HLSAssetSegmentNode * _Nonnull node, BOOL * _Nonnull stop) {
            id<HLSAssetSegment> _Nullable fullSegment = node.fullContent;
            if ( fullSegment != nil ) {
                // trim redundant contents
                if ( node.numberOfContents > 1 ) [self trimRedundantContentsForNode:node reservedContent:fullSegment];
                if ( isFullyTrimmed && node.numberOfContents > 1 ) isFullyTrimmed = NO;
            }
            else {
                if ( isAllSegmentsCached ) isAllSegmentsCached = NO;
                if ( isFullyTrimmed ) isFullyTrimmed = NO;
                // check continue for trim redundant contents
            }
        }];
        mAssembled = isAllSegmentsCached;
        if ( isFullyTrimmed ) mFullyTrimmed = isFullyTrimmed;
    }
    else if ( mParser.variantStream != nil ) {
        BOOL isVariantStreamStored = mVariantStreamAsset.isStored;
        BOOL isAudioRenditionStored = mAudioRenditionAsset == nil || mAudioRenditionAsset.isStored;
        BOOL isVideoRenditionStored = mVideoRenditionAsset == nil || mVideoRenditionAsset.isStored;
        BOOL isSubtitlesRenditionStored = mParser.subtitlesRendition == nil || mSubtitlesContent != nil;
        mAssembled = isVariantStreamStored && isAudioRenditionStored && isVideoRenditionStored && isSubtitlesRenditionStored;
        mFullyTrimmed = YES;
    }
    else {
        mAssembled = YES;
        mFullyTrimmed = YES;
    }
    
    if ( mAssembled ) {
        for ( id<MCSAssetObserver> observer in MCSAllHashTableObjects(mObservers) ) {
            if ( [observer respondsToSelector:@selector(assetDidStore:)] ) {
                [observer assetDidStore:self];
            }
        }
    }
}

- (void)trimRedundantContentsForNode:(HLSAssetSegmentNode *)node reservedContent:(id<HLSAssetSegment>)fullSegment {
    // 同一段segment可能存在多个文件
    // 删除多余的无用的content
    [node removeContentsWithTest:^BOOL(id<HLSAssetSegment>  _Nonnull content, BOOL * _Nonnull stop) {
        if ( content != fullSegment && content.readwriteCount == 0 ) {
            [mProvider removeSegment:content];
            return YES;
        }
        return NO;
    }];
}
@end
