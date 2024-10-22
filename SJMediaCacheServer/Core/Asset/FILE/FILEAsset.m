//
//  MCSAsset.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "FILEAsset.h"
#import "FILEAssetContentProvider.h"
#import "FILEAssetReader.h"
#import "MCSUtils.h"
#import "MCSConsts.h"
#import "MCSConfiguration.h"
#import "MCSRootDirectory.h"
#import "NSFileHandle+MCS.h"
#import "MCSAssetManager.h"
#import "MCSRequest.h"

@interface FILEAsset () {
    NSHashTable<id<MCSAssetObserver>> *mObservers;
    MCSConfiguration *mConfiguration;
    FILEAssetContentProvider *mProvider;
    FILEAssetContentNodeList *mNodeList;
    BOOL mPrepared;
    BOOL mMetadataReady;
    BOOL mAssembled; // 是否已组合完成, 是否已得到完整内容; 虽然得到了完整内容, 但是文件夹下可能还存在正在读取的冗余数据;
    BOOL mFullyTrimmed; // 所有冗余数据都已删除;
}

@property (nonatomic) NSInteger id; // saveable
@property (nonatomic, copy) NSString *name; // saveable
@property (nonatomic, copy, nullable) NSString *pathExtension; // saveable
@property (nonatomic) NSUInteger totalLength;  // saveable
@end

@implementation FILEAsset
@synthesize id = _id;
@synthesize name = _name;

+ (NSString *)sql_primaryKey {
    return @"id";
}

+ (NSArray<NSString *> *)sql_autoincrementlist {
    return @[@"id"];
}

+ (NSArray<NSString *> *)sql_blacklist {
    return @[@"readwriteCount", @"isStored", @"configuration", @"contents", @"provider"];
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
        if ( !mPrepared ) {
            mPrepared = YES;
            mConfiguration = MCSConfiguration.alloc.init;
            NSString *directory = [MCSRootDirectory assetPathForFilename:self.name];
            mProvider = [FILEAssetContentProvider contentProviderWithDirectory:directory];
            mNodeList = [FILEAssetContentNodeList.alloc init];
            [mProvider.contents enumerateObjectsUsingBlock:^(id<MCSAssetContent>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [mNodeList attachContentToNode:obj placement:obj.position];
            }];
            mMetadataReady = mNodeList.count != 0;
            [self _restructureContents];
        }
    }
}

- (id<MCSConfiguration>)configuration {
    return mConfiguration;
}

- (NSString *)path {
    return [MCSRootDirectory assetPathForFilename:_name];
}

#pragma mark - mark

- (MCSAssetType)type {
    return MCSAssetTypeFILE;
}

/// 遍历内容节点
///
/// 在获取某个节点的 content 之后, 如要使用请在回调块中调用 readwriteRetain 以防 content 被删除;
- (void)enumerateContentNodesUsingBlock:(void(NS_NOESCAPE ^)(FILEAssetContentNode *node, BOOL *stop))block {
    @synchronized (self) {
        [mNodeList enumerateNodesUsingBlock:block];
    }
}

- (BOOL)isStored {
    @synchronized (self) {
        if ( !mAssembled ) {
            [self _restructureContents];
        }
        return mAssembled;
    }
}
- (nullable NSString *)pathExtension {
    @synchronized (self) {
        return _pathExtension;
    }
}

- (NSUInteger)totalLength {
    @synchronized (self) {
        return _totalLength;
    }
}

- (float)completeness {
    @synchronized (self) {
        if ( mAssembled ) return 1;
        if ( !mMetadataReady ) return 0;
        __block id<MCSAssetContent> prev = nil;
        __block UInt64 length = 0;
        [mNodeList enumerateNodesUsingBlock:^(FILEAssetContentNode * _Nonnull node, BOOL * _Nonnull stop) {
            id<MCSAssetContent> cur = node.longestContent;
            length += cur.length;
            UInt64 prevPosition = prev.position + prev.length;
            if ( prevPosition > cur.position ) length -= (prevPosition - cur.position);
            prev = cur;
        }];
        return length * 1.0f / _totalLength;
    }
}

/// 该操作将会对 content 进行一次 readwriteRetain, 请在不需要时, 调用一次 readwriteRelease.
- (nullable id<MCSAssetContent>)createContentWithDataType:(MCSDataType)dataType response:(id<MCSDownloadResponse>)response error:(NSError **)error {
    @synchronized (self) {
        BOOL shouldNotify = NO;
        @try {
            switch ( dataType ) {
                case MCSDataTypeHLSMask:
                case MCSDataTypeHLSPlaylist:
                case MCSDataTypeHLSAESKey:
                case MCSDataTypeHLSSegment:
                case MCSDataTypeHLSSubtitles:
                case MCSDataTypeHLS:
                case MCSDataTypeFILEMask:
                    /* return */
                    return nil;
                case MCSDataTypeFILE:
                    break;
            }
            NSString *pathExtension = response.pathExtension;
            NSUInteger totalLength = response.totalLength;
            NSUInteger offset = response.range.location;
            if ( !mMetadataReady ) {
                mMetadataReady = YES;
                _totalLength = totalLength;
                _pathExtension = pathExtension;
                shouldNotify = YES;
            }
            id<MCSAssetContent> content = [mProvider createContentAtOffset:offset pathExtension:_pathExtension error:error];
            if ( content != nil ) {
                [content readwriteRetain];
                [mNodeList attachContentToNode:content placement:content.position];
            }
            return content;
        }
        @finally {
            if ( shouldNotify ) {
                for ( id<MCSAssetObserver> observer in MCSAllHashTableObjects(mObservers) ) {
                    if ( [observer respondsToSelector:@selector(assetDidLoadMetadata:)] ) {
                        [observer assetDidLoadMetadata:self];
                    }
                }
            }
        }
    }
}

- (nullable id<MCSAssetReader>)readerWithRequest:(id<MCSRequest>)request networkTaskPriority:(float)networkTaskPriority readDataDecryptor:(NSData *(^_Nullable)(NSURLRequest *request, NSUInteger offset, NSData *data))readDataDecryptor delegate:(nullable id<MCSAssetReaderDelegate>)delegate {
    return [FILEAssetReader.alloc initWithAsset:self request:request networkTaskPriority:networkTaskPriority readDataDecryptor:readDataDecryptor delegate:delegate];
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
        [mNodeList removeAllNodes];
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

#pragma mark - mark

- (void)readwriteRelease {
    @synchronized (self) {
        [super readwriteRelease];
        if ( !mFullyTrimmed ) [self _restructureContents];
    }
}

#pragma mark - mark

/// 重组内容. 合并数据并移除多余内容;
///
- (void)_restructureContents {
    if ( !mFullyTrimmed && mMetadataReady ) {
        FILEAssetContentNode *_Nullable head = mNodeList.head;
        FILEAssetContentNode *_Nullable curNode = head;
        while ( curNode != nil ) {
            if ( curNode.numberOfContents > 1 ) [self _trimRedundantContentsForNode:curNode];
            FILEAssetContentNode *_Nullable nextNode = curNode.next;
            if ( nextNode == nil ) break; // break;
            if ( nextNode.numberOfContents > 1 ) [self _trimRedundantContentsForNode:curNode];
            id<MCSAssetContent> _Nullable writer = curNode.idleContent;
            id<MCSAssetContent> _Nullable reader = nextNode.longestContent;
            BOOL isNextNodeRemoved = NO;
            if ( writer != nil && reader != nil ) {
                BOOL isDataMerged = [self _mergeContentDataTo:writer from:reader];
                if ( isDataMerged && reader.readwriteCount == 0 ) { // remove reader;
                    [mProvider removeContent:reader];
                    [nextNode removeContent:reader];
                    if ( nextNode.numberOfContents == 0 ) {
                        [mNodeList removeNode:nextNode];
                        isNextNodeRemoved = YES;
                    }
                }
            }
            if ( !isNextNodeRemoved ) {
                curNode = nextNode;
            }
        }

        if ( head != nil && head.longestContent.length == _totalLength ) {
            if ( !mAssembled ) {
                mAssembled = YES;
                for ( id<MCSAssetObserver> observer in MCSAllHashTableObjects(mObservers) ) {
                    if ( [observer respondsToSelector:@selector(assetDidStore:)] ) {
                        [observer assetDidStore:self];
                    }
                }
            }
            
            if ( !mFullyTrimmed ) {
                mFullyTrimmed = mNodeList.count == 1 && head.numberOfContents == 1;
            }
        }
    }
}

/// unlocked
- (void)_trimRedundantContentsForNode:(FILEAssetContentNode *)node {
    if ( node != nil && node.numberOfContents > 1 ) {
        // 同一段位置可能存在多个文件
        // 删除多余的无用的content
        id<MCSAssetContent> longestContent = node.longestContent;
        [node removeContentsWithTest:^BOOL(id<MCSAssetContent>  _Nonnull content, BOOL * _Nonnull stop) {
            if ( content != longestContent && content.readwriteCount == 0 ) {
                [mProvider removeContent:content];
                return YES;
            }
            return NO;
        }];
    }
}

/// 合并数据; 被合并后返回 YES;
- (BOOL)_mergeContentDataTo:(id<MCSAssetContent>)writer from:(id<MCSAssetContent>)reader {
    if ( writer.readwriteCount != 0 ) return NO; // 如果 writer 正在被操作则直接 return;
    NSRange curRange = { writer.position, writer.length };
    NSRange nextRange = { reader.position, reader.length };
    // 如果 writer 中包含 reader 的所有数据, return YES;
    if      ( MCSNSRangeContains(curRange, nextRange) ) {
        return YES;
    }
    // 连续的 或 存在交集;
    // 合并未相交部分的数据;
    else if ( NSMaxRange(curRange) == nextRange.location || NSIntersectionRange(curRange, nextRange).length != 0 ) {
        UInt64 capacity = 8 * 1024 * 1024;
        // 读取 read 中未相交的部分;
        NSRange readRange = { NSMaxRange(curRange), NSMaxRange(nextRange) - NSMaxRange(curRange) };
        NSError *error = nil;
        UInt64 position = readRange.location;
        while ( true ) { @autoreleasepool {
            NSData *data = [reader readDataAtPosition:position capacity:capacity error:&error];
            if ( error != nil || data.length == 0 )
                break;
            if ( ![writer writeData:data error:&error] )
                break;
            position += data.length;
            if ( position == NSMaxRange(readRange) ) break;
        }}
        [reader closeRead];
        [writer closeWrite];
        return error == nil;
    }
    return NO;
}
@end
