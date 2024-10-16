//
//  MCSAsset.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "FILEAsset.h"
#import "FILEAssetContentProvider.h"
#import "MCSUtils.h"
#import "MCSConsts.h"
#import "MCSConfiguration.h"
#import "MCSRootDirectory.h"
#import "NSFileHandle+MCS.h"
#import "MCSAssetManager.h"

@interface FILEAsset () {
    MCSConfiguration *mConfiguration;
    FILEAssetContentProvider *mProvider;
    MCSAssetContentNodeList *mNodeList;
    BOOL mPrepared;
    BOOL mMetadataReady;
    BOOL mAssembled; // 文件组合完成; 已得到完整文件;
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

- (void)prepare {
    @synchronized (self) {
        NSParameterAssert(self.name != nil);
        if ( !mPrepared ) {
            mPrepared = YES;
            mConfiguration = MCSConfiguration.alloc.init;
            NSString *directory = [MCSRootDirectory assetPathForFilename:self.name];
            mProvider = [FILEAssetContentProvider contentProviderWithDirectory:directory];
            mNodeList = [MCSAssetContentNodeList.alloc init];
            [mProvider.contents enumerateObjectsUsingBlock:^(id<MCSAssetContent>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [mNodeList attachContentToNode:obj placement:obj.startPositionInAsset];
            }];
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
- (void)enumerateContentNodesUsingBlock:(void(NS_NOESCAPE ^)(MCSAssetContentNode *node, BOOL *stop))block {
    @synchronized (self) {
        [mNodeList enumerateNodesUsingBlock:block];
    }
}

- (BOOL)isStored {
    @synchronized (self) {
        return mAssembled;
    }
}

- (nullable NSString *)filepathForContent:(id<MCSAssetContent>)content {
    return [mProvider contentFilepath:content];
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

/// 该操作将会对 content 进行一次 readwriteRetain, 请在不需要时, 调用一次 readwriteRelease.
- (nullable id<MCSAssetContent>)createContentReadwriteWithDataType:(MCSDataType)dataType response:(id<MCSDownloadResponse>)response {
    switch ( dataType ) {
        case MCSDataTypeHLSMask:
        case MCSDataTypeHLSPlaylist:
        case MCSDataTypeHLSAESKey:
        case MCSDataTypeHLSMediaSegment:
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
    id<MCSAssetContent>content = nil;
    BOOL shouldNotify = NO;
    @synchronized (self) {
        if ( !mMetadataReady ) {
            mMetadataReady = YES;
            _totalLength = totalLength;
            _pathExtension = pathExtension;
            shouldNotify = YES;
        }
        
        content = [mProvider createContentAtOffset:offset pathExtension:_pathExtension];
        [content readwriteRetain];
        if ( content != nil ) [mNodeList attachContentToNode:content placement:content.startPositionInAsset];
    }
    
    if ( shouldNotify ) [MCSAssetManager.shared assetMetadataDidLoad:self];
    return content;
}

- (void)readwriteCountDidChange:(NSInteger)count {
    if ( count == 0 ) {
        @synchronized (self) {
            [self _restructureContents];
        }
    }
}

/// 拆分重组内容. 将内容按指定字节拆分重组
///
/// unlocked
- (void)_restructureContents {
    if ( mAssembled || !mMetadataReady || self.readwriteCount != 0 ) return;
    UInt64 capacity = 1 * 1024 * 1024;
    MCSAssetContentNode *curNode = mNodeList.head;
    while ( curNode != nil ) {
        [self _trimExcessContentsForNode:curNode];
        MCSAssetContentNode *nextNode = curNode.next;
        if ( nextNode == nil ) break;
        [self _trimExcessContentsForNode:nextNode];
        
        id<MCSAssetContent> write = curNode.longestContent;
        id<MCSAssetContent> read = nextNode.longestContent;
        
        NSRange curRange = {write.startPositionInAsset, write.length};
        NSRange nextRange = {read.startPositionInAsset, read.length};
        if      ( MCSNSRangeContains(curRange, nextRange) ) {
            [mProvider removeContent:read];
            [mNodeList removeNode:nextNode];
        }
        else if ( NSMaxRange(curRange) == nextRange.location || NSIntersectionRange(curRange, nextRange).length != 0 ) { // 连续的或存在交集
            NSRange readRange = { NSMaxRange(curRange), NSMaxRange(nextRange) - NSMaxRange(curRange) };   // 读取read中未相交的部分
            [write readwriteRetain];
            [read readwriteRetain];
            NSError *error = nil;
            UInt64 position = readRange.location;
            while ( true ) { @autoreleasepool {
                NSData *data = [read readDataAtPosition:position capacity:capacity error:&error];
                if ( error != nil || data.length == 0 )
                    break;
                if ( ![write writeData:data error:&error] )
                    break;
                position += data.length;
                if ( position == NSMaxRange(readRange) ) break;
            }}
            [read readwriteRelease];
            [read closeRead];
            [write readwriteRelease];
            [write closeWrite];
            
            if ( error == nil ) {
                [mProvider removeContent:read];
                [mNodeList removeNode:nextNode];
            }
        }
        curNode = curNode.next;
    }
    
    mAssembled = mNodeList.head.longestContent.length == _totalLength;
}

/// unlocked
- (void)_trimExcessContentsForNode:(MCSAssetContentNode *)node {
    if ( node.numberOfContents > 1 ) {
        // 同一段位置可能存在多个文件
        // 删除多余的无用的content
        id<MCSAssetContent> longestContent = node.longestContent;
        [node trimExcessContentsWithTest:^BOOL(id<MCSAssetContent>  _Nonnull content, BOOL * _Nonnull stop) {
            if ( content != longestContent && content.readwriteCount == 0 ) {
                [mProvider removeContent:content];
                return YES;
            }
            return NO;
        }];
    }
}
@end
