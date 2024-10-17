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


// 1. 如何从proxyURL中知道将要请求的数据的类型 MCSDataType


UInt64 const HLS_ASSET_PLAYLIST_NODE_PLACEMENT = 0;

@interface HLSAsset () {
    MCSConfiguration *mConfiguration;
    HLSAssetContentProvider *mProvider;
    id<MCSAssetContent> _Nullable mPlaylistContent;
    NSMutableDictionary<NSString *, id<MCSAssetContent>> * _Nullable mAESKeyContents; // { filename: content }
    
    HLSAssetParser *_Nullable mParser;
    NSMutableArray<id<HLSAssetTsContent>> *mTsContents;
    BOOL mPrepared;
}

@property (nonatomic) NSInteger id; // saveable
@property (nonatomic, copy) NSString *name; // saveable
@property (nonatomic, weak, nullable) HLSAsset *root;
@end

@implementation HLSAsset
@synthesize id = _id;
@synthesize isStored = _isStored;

+ (NSString *)sql_primaryKey {
    return @"id";
}

+ (NSArray<NSString *> *)sql_autoincrementlist {
    return @[@"id"];
}

+ (NSArray<NSString *> *)sql_blacklist {
    return @[@"readwriteCount", @"isStored", @"configuration", @"contents", @"parser", @"root"];
}

- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    _name = name.copy;
    return self;
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
        
        // playlist 与 aes key 都属于小文件, 目录中只要存在对应文件就说明已下载完毕;
        
        // find proxy playlist file
        NSString *proxyPlaylistFilePath = [mProvider getPlaylistFilePath];
        if ( [NSFileManager.defaultManager fileExistsAtPath:proxyPlaylistFilePath] ) {
            NSError *error = nil;
            mParser = [HLSAssetParser.alloc initWithProxyPlaylist:[NSString stringWithContentsOfFile:proxyPlaylistFilePath encoding:NSUTF8StringEncoding error:&error]];
            if ( mParser != nil ) {
                mPlaylistContent = [MCSAssetContent.alloc initWithFilePath:proxyPlaylistFilePath startPositionInAsset:0 length:[NSFileManager.defaultManager mcs_fileSizeAtPath:proxyPlaylistFilePath]];
                
                // find existing contents
                [mParser.allItems enumerateObjectsUsingBlock:^(id<HLSURIItem>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    switch (obj.type) {
                        case MCSDataTypeHLSAESKey: {
                            
                        }
                            break;
                        case MCSDataTypeHLSSegment: {
                            
                        }
                            break;
                        case MCSDataTypeHLSPlaylist:
                        case MCSDataTypeHLS:
                        case MCSDataTypeHLSMask:
                        case MCSDataTypeFILEMask:
                        case MCSDataTypeFILE:
                            break;
                    }
                }];
            }
        }
        
        
        
#warning next ...
//        mTsContents = [(mProvider.TsContents ?: @[]) mutableCopy];
        [self _mergeContents];
    }
}

- (id<MCSConfiguration>)configuration {
    return mConfiguration;
}

- (NSString *)path {
    return [MCSRootDirectory assetPathForFilename:_name];
}

#pragma mark - mark

- (nullable HLSAssetParser *)parser {
    @synchronized (self) {
        return mParser;
    }
}

- (MCSAssetType)type {
    return MCSAssetTypeHLS;
}

- (nullable NSArray<id<HLSAssetTsContent>> *)TsContents {
    @synchronized (self) {
        return mTsContents;
    }
}

- (BOOL)isStored {
    @synchronized (self) {
        return _isStored;
    }
}

- (NSString *)playlistFilePath {
    return [mProvider getPlaylistFilePath];
}

- (NSString *)getPlaylistRelativePath {
    return [mProvider getPlaylistRelativePath];
}

- (NSString *)AESKeyFilePathWithURL:(NSURL *)URL {
    return [mProvider getAESKeyFilePath:[MCSURL.shared nameWithUrl:URL.absoluteString suffix:HLS_SUFFIX_AES_KEY]];
}

- (NSUInteger)tsCount {
    @synchronized (self) {
        return mParser.segmentsCount;
    }
}

@synthesize root = _root;
- (void)setRoot:(nullable HLSAsset *)root {
    @synchronized (self) {
        _root = root;
    }
}

- (nullable HLSAsset *)root {
    @synchronized (self) {
        return _root;
    }
}


- (nullable id<MCSAssetReader>)readerWithRequest:(id<MCSRequest>)request networkTaskPriority:(float)networkTaskPriority readDataDecoder:(NSData *(^_Nullable)(NSURLRequest *request, NSUInteger offset, NSData *data))readDataDecoder delegate:(nullable id<MCSAssetReaderDelegate>)delegate {
    return [HLSAssetReader.alloc initWithAsset:self request:request networkTaskPriority:networkTaskPriority readDataDecoder:readDataDecoder delegate:delegate];
}

- (nullable id<MCSAssetContent>)getPlaylistContent {
    @synchronized (self) {
        return mPlaylistContent != nil ? [mPlaylistContent readwriteRetain] : nil;
    }
}

- (nullable id<MCSAssetContent>)createPlaylistContent:(NSString *)proxyPlaylist error:(out NSError **)errorPtr {
    @synchronized (self) {
        if ( mPlaylistContent == nil ) {
            NSError *error = nil;
            NSString *filePath = [mProvider getPlaylistFilePath];
            NSData *data = [proxyPlaylist dataUsingEncoding:NSUTF8StringEncoding];
            if ( [data writeToFile:filePath options:NSDataWritingAtomic error:&error] ) {
                mParser = [HLSAssetParser.alloc initWithProxyPlaylist:proxyPlaylist];
                mPlaylistContent = [MCSAssetContent.alloc initWithFilePath:filePath startPositionInAsset:0 length:data.length];
            }
            if ( error != nil && errorPtr != NULL ) *errorPtr = error;
        }
        return mPlaylistContent != nil ? [mPlaylistContent readwriteRetain] : nil;
    }
}

- (nullable id<MCSAssetContent>)getAESKeyContentWithOriginalURL:(NSURL *)originalURL {
    @synchronized (self) {
        NSString *filename = [MCSURL.shared proxyFilenameWithOriginalURL:originalURL dataType:MCSDataTypeHLSAESKey];
        
        return nil;
    }
}
- (nullable id<MCSAssetContent>)createAESKeyContentWithOriginalURL:(NSURL *)originalURL data:(NSData *)data error:(out NSError **)error {
    @synchronized (self) {
        return nil;
    }
}









- (nullable id<HLSAssetTsContent>)createTsContentWithResponse:(id<MCSDownloadResponse>)response {
    NSString *TsContentType = response.contentType;
    __block BOOL isUpdated = NO;
    __block id<HLSAssetTsContent>content = nil;
    @synchronized (self) {
//        if ( ![TsContentType isEqualToString:_TsContentType] ) {
//            _TsContentType = TsContentType;
//            isUpdated = YES;
//        }
        
        NSString *name = [MCSURL.shared nameWithUrl:response.URL.absoluteString suffix:HLS_SUFFIX_TS];
        
        if ( response.statusCode == MCS_RESPONSE_CODE_PARTIAL_CONTENT ) {
            content = [mProvider createTsContentWithName:name totalLength:response.totalLength rangeInAsset:response.range];
        }
        else {
            content = [mProvider createTsContentWithName:name totalLength:response.totalLength];
        }
        
        [mTsContents addObject:content];
    }
    
//    if ( isUpdated )
//        [NSNotificationCenter.defaultCenter postNotificationName:MCSAssetMetadataDidLoadNotification object:self];
    return content;
}
 
- (nullable id<HLSAssetTsContent>)TsContentForRequest:(NSURLRequest *)request {
    NSString *name = [MCSURL.shared nameWithUrl:request.URL.absoluteString suffix:HLS_SUFFIX_TS];
    __block id<HLSAssetTsContent>ts = nil;
    @synchronized (self) {
        // range
        NSRange r = NSMakeRange(0, 0);
        BOOL isRangeRequest = MCSRequestIsRangeRequest(request);
        MCSRequestContentRange range = MCSRequestContentRangeUndefined;
        if ( isRangeRequest ) {
            range = MCSRequestGetContentRange(request.allHTTPHeaderFields);
            r = MCSRequestRange(range);
        }
        
        for ( id<HLSAssetTsContent>content in mTsContents ) {
            if ( ![content.name isEqualToString:name] ) continue;
            if ( isRangeRequest && !NSEqualRanges(r, content.rangeInAsset) ) continue;
            
            if ( content.length == content.rangeInAsset.length ) {
                ts = content;
                break;
            }
        }
    }
    return ts;
}

/// 将返回如下两种content, 如果未满足条件, 则返回nil
///
///     - 如果ts已缓存完毕, 则返回完整的content
///
///     - 如果ts被缓存了一部分(可能存在多个), 则将返回长度最长的并且readwrite为0的content
///
/// 该操作将会对 content 进行一次 readwriteRetain, 请在不需要时, 调用一次 readwriteRelease.
///
- (nullable id<HLSAssetTsContent>)TsContentReadwriteForRequest:(NSURLRequest *)request {
    NSString *name = [MCSURL.shared nameWithUrl:request.URL.absoluteString suffix:HLS_SUFFIX_TS];
    __block id<HLSAssetTsContent>_ts = nil;
    @synchronized (self) {
        // range
        BOOL isRangeRequest = MCSRequestIsRangeRequest(request);
        NSRange requestRange = NSMakeRange(0, 0);
        if ( isRangeRequest ) {
            MCSRequestContentRange contentRange = MCSRequestGetContentRange(request.allHTTPHeaderFields);
            requestRange = MCSRequestRange(contentRange);
        }
        
        for ( id<HLSAssetTsContent>cur in mTsContents ) {
            if ( ![cur.name isEqualToString:name] )
                continue;
            if ( isRangeRequest && !NSEqualRanges(requestRange, cur.rangeInAsset) )
                continue;

            // 已缓存完毕
            if ( cur.length == cur.rangeInAsset.length ) {
                _ts = cur;
                break;
            }
            
            // 未缓存完成的, 则返回length最长的content
            if ( cur.readwriteCount == 0 ) {
                if ( _ts.length < cur.length ) {
                    _ts = cur;
                }
            }
        }
        
        if ( _ts != nil ) {
            [_ts readwriteRetain];
        }
    }
    return _ts;
}


- (nullable id<MCSAssetContent>)createContentReadwriteWithDataType2:(MCSDataType)dataType response:(id<MCSDownloadResponse>)response {
    switch ( dataType ) {
        case MCSDataTypeFILEMask:
        case MCSDataTypeFILE:
        case MCSDataTypeHLSMask:
            /* return */
            return nil;
        case MCSDataTypeHLSPlaylist:
        case MCSDataTypeHLSAESKey:
        case MCSDataTypeHLS:
        case MCSDataTypeHLSSegment:
            break;
    }
    
    return nil;
}

- (nullable id<MCSAssetContent>)createContentReadwriteWithDataType:(MCSDataType)dataType response:(id<MCSDownloadResponse>)response {
    switch ( dataType ) {
        case MCSDataTypeHLSMask:
        case MCSDataTypeHLSPlaylist:
        case MCSDataTypeHLSAESKey:
        case MCSDataTypeHLS:
        case MCSDataTypeFILEMask:
        case MCSDataTypeFILE:
            /* return */
            return nil;
        case MCSDataTypeHLSSegment:
            break;
    }
    
    NSString *TsContentType = response.contentType;
    __block BOOL isUpdated = NO;
    __block id<HLSAssetTsContent>content = nil;
    @synchronized (self) {
//        if ( ![TsContentType isEqualToString:_TsContentType] ) {
//            _TsContentType = TsContentType;
//            isUpdated = YES;
//        }
        
        NSString *name = [MCSURL.shared nameWithUrl:response.URL.absoluteString suffix:HLS_SUFFIX_TS];
        
        if ( response.statusCode == MCS_RESPONSE_CODE_PARTIAL_CONTENT ) {
            content = [mProvider createTsContentWithName:name totalLength:response.totalLength rangeInAsset:response.range];
        }
        else {
            content = [mProvider createTsContentWithName:name totalLength:response.totalLength];
        }
        [content readwriteRetain];
        [mTsContents addObject:content];
    }
//    
//    if ( isUpdated )
//        [NSNotificationCenter.defaultCenter postNotificationName:MCSAssetMetadataDidLoadNotification object:self];
    return content;
}

#pragma mark - readwrite

- (void)readwriteCountDidChange:(NSInteger)count {
    if ( count == 0 ) {
        [self _mergeContents];
    }
}

// 合并文件
- (void)_mergeContents {
    if ( _root != nil && _root.readwriteCount != 0 ) return;
    if ( self.readwriteCount != 0 ) return;
    if ( _isStored ) return;
    if ( mTsContents.count == 0 ) return;
    
    NSMutableArray<id<HLSAssetTsContent>> *contents = mTsContents.copy;
    NSMutableArray<id<HLSAssetTsContent>> *deletes = NSMutableArray.alloc.init;
    for ( NSInteger i = 0 ; i < contents.count ; ++ i ) {
        id<HLSAssetTsContent>obj1 = contents[i];
        for ( NSInteger j = i + 1 ; j < contents.count ; ++ j ) {
            id<HLSAssetTsContent>obj2 = contents[j];
            if ( [obj1.name isEqualToString:obj2.name] && NSEqualRanges(obj1.rangeInAsset, obj2.rangeInAsset) ) {
                [deletes addObject:obj1.length >= obj2.length ? obj2 : obj1];
            }
        }
    }
    
    if ( deletes.count != 0 ) {
        for ( id<HLSAssetTsContent>content in deletes ) { [mProvider removeTsContent:content]; }
        [mTsContents removeObjectsInArray:deletes];
    }
    
    if ( mTsContents.count == mParser.segmentsCount ) {
        BOOL isStoredAllContents = YES;
        for ( id<HLSAssetTsContent>content in mTsContents ) {
            if ( content.length != content.totalLength ) {
                isStoredAllContents = NO;
                break;
            }
        }
        _isStored = isStoredAllContents;
    }
}
@end
