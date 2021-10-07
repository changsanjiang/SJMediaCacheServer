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
#import "MCSQueue.h"

@interface FILEAssetContentNode : NSObject<FILEAssetContentNode>
@property (nonatomic, readonly) UInt64 startPositionInAsset;
@property (nonatomic, readonly, nullable) id<MCSAssetContent> maximumLengthContent;
@property (nonatomic, readonly, nullable) NSArray<id<MCSAssetContent>> *allContents;
@end

@interface FILEAssetContentNode ()
@property (nonatomic, unsafe_unretained, nullable) FILEAssetContentNode *prev;
@property (nonatomic, unsafe_unretained, nullable) FILEAssetContentNode *next;
- (void)addContent:(id<MCSAssetContent>)content;
@end

@implementation FILEAssetContentNode {
    NSMutableArray<id<MCSAssetContent>> *mContents;
}
- (instancetype)init {
    self = [super init];
    if ( self ) {
        mContents = [NSMutableArray arrayWithCapacity:1];
    }
    return self;
}

- (UInt64)startPositionInAsset {
    return mContents.firstObject.startPositionInAsset;
}

- (nullable id<MCSAssetContent>)maximumLengthContent {
    id<MCSAssetContent> retv = mContents.firstObject;
    for ( NSInteger i = 1 ; i < mContents.count ; ++ i ) {
        id<MCSAssetContent> content = mContents[i];
        if ( content.length > retv.length ) {
            retv = content;
        }
    }
    return retv;
}

- (void)addContent:(id<MCSAssetContent>)content {
    [mContents addObject:content];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@: <%p> { startPosisionInAsset: %llu, maximumLength: %llu, contents: %lu };\n", NSStringFromClass(self.class), self, self.startPositionInAsset, self.maximumLengthContent.length, (unsigned long)mContents.count];
}
@end

@interface FILEAssetContentNodeList : NSObject
- (instancetype)initWithContents:(nullable NSArray<id<MCSAssetContent>> *)contents;
@property (nonatomic, readonly, nullable) FILEAssetContentNode *head;
@property (nonatomic, readonly, nullable) FILEAssetContentNode *tail;
- (void)bringContentToNode:(id<MCSAssetContent>)content;
- (void)removeNode:(FILEAssetContentNode *)node;
- (void)enumerateContentNodesUsingBlock:(void(NS_NOESCAPE ^)(id<FILEAssetContentNode> node, BOOL *stop))block;
@end

@implementation FILEAssetContentNodeList {
    NSMutableDictionary<NSNumber *, FILEAssetContentNode *> *mNodes;
}
- (instancetype)initWithContents:(nullable NSArray<id<MCSAssetContent>> *)contents {
    self = [super init];
    mNodes = NSMutableDictionary.dictionary;
    for ( id<MCSAssetContent> content in contents ) {
        [self bringContentToNode:content];
    }
    return self;
}

- (void)bringContentToNode:(id<MCSAssetContent>)content {
    UInt64 curNodePosition = content.startPositionInAsset;
    NSNumber *curNodeKey = @(curNodePosition);
    FILEAssetContentNode *curNode = mNodes[curNodeKey];
    if ( curNode == nil ) {
        // create new node
        //
        curNode = [FILEAssetContentNode.alloc init];
        mNodes[curNodeKey] = curNode;
         
        // restructure nodes position
        //
        // prevNode.position < curNode.position < nextNode.position
        //
        FILEAssetContentNode *prevNode = _tail;
        FILEAssetContentNode *nextNode = nil;
        while ( prevNode.startPositionInAsset > curNodePosition ) {
            nextNode = prevNode;
            prevNode = prevNode.prev;
        }
        
        prevNode.next = curNode;
        curNode.prev = prevNode;
        curNode.next = nextNode;
        
        if ( _head == nil || _head.startPositionInAsset > curNodePosition ) {
            _head = curNode;
        }
        
        if ( _tail == nil || _tail.startPositionInAsset < curNodePosition ) {
            _tail = curNode;
        }
    }
    [curNode addContent:content];
}

- (void)enumerateContentNodesUsingBlock:(void(NS_NOESCAPE ^)(id<FILEAssetContentNode> node, BOOL *stop))block {
    BOOL stop = NO;
    FILEAssetContentNode *cur = _head;
    while ( cur != nil ) {
        block(cur, &stop);
        cur = cur.next;
        if ( stop ) break;;
    }
}

- (void)removeNode:(FILEAssetContentNode *)node {
    FILEAssetContentNode *prevNode = node.prev;
    FILEAssetContentNode *nextNode = node.next;
    if ( prevNode != nil ) nextNode.prev = prevNode;
    if ( nextNode != nil ) prevNode.next = nextNode;

    if ( _head == node ) _head = nextNode;
    if ( _tail == node ) _tail = prevNode;
    
    NSNumber *nodeKey = @(node.startPositionInAsset);
    [mNodes removeObjectForKey:nodeKey];
}
@end


@interface FILEAsset () {
    FILEAssetContentProvider *mProvider;
    FILEAssetContentNodeList *mNodeList;
    BOOL mIsPrepared;
}

@property (nonatomic) NSInteger id; // saveable
@property (nonatomic, copy) NSString *name; // saveable
@property (nonatomic, copy, nullable) NSString *pathExtension; // saveable
@property (nonatomic, copy, nullable) NSString *contentType; // saveable
@property (nonatomic) NSUInteger totalLength;  // saveable
@end

@implementation FILEAsset
@synthesize id = _id;
@synthesize name = _name;
@synthesize configuration = _configuration;
@synthesize isStored = _isStored;

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
    if ( self ) {
        _name = name.copy;
    }
    return self;
}

- (void)prepare {
    mcs_queue_sync(^{
        NSParameterAssert(self.name != nil);
        if ( mIsPrepared ) return;
        mIsPrepared = YES;
        NSString *directory = [MCSRootDirectory assetPathForFilename:self.name];
        _configuration = MCSConfiguration.alloc.init;
        mProvider = [FILEAssetContentProvider contentProviderWithDirectory:directory];
        mNodeList = [FILEAssetContentNodeList.alloc initWithContents:mProvider.contents];
        [self _mergeContents];
    });
}

- (NSString *)path {
    return [MCSRootDirectory assetPathForFilename:_name];
}

#pragma mark - mark

- (MCSAssetType)type {
    return MCSAssetTypeFILE;
}

- (void)enumerateContentNodesUsingBlock:(void(NS_NOESCAPE ^)(id<FILEAssetContentNode> node, BOOL *stop))block {
    mcs_queue_sync(^{
        [mNodeList enumerateContentNodesUsingBlock:block];
    });
}

- (BOOL)isStored {
    __block BOOL isStored = NO;
    mcs_queue_sync(^{
        isStored = _isStored;
    });
    return isStored;
}

- (nullable NSString *)filepathForContent:(id<MCSAssetContent>)content {
    return [mProvider contentFilepath:content];
}

- (nullable NSString *)pathExtension {
    __block NSString *pathExtension = nil;
    mcs_queue_sync(^{
        pathExtension = _pathExtension;
    });
    return pathExtension;
}

- (nullable NSString *)contentType {
    __block NSString *contentType = nil;
    mcs_queue_sync(^{
        contentType = _contentType;
    });
    return contentType;
}

- (NSUInteger)totalLength {
    __block NSUInteger totalLength = 0;
    mcs_queue_sync(^{
        totalLength = _totalLength;
    });
    return totalLength;
}

/// 该操作将会对 content 进行一次 readwriteRetain, 请在不需要时, 调用一次 readwriteRelease.
- (nullable id<MCSAssetContent>)createContentReadwriteWithDataType:(MCSDataType)dataType response:(id<MCSDownloadResponse>)response {
    switch ( dataType ) {
        case MCSDataTypeHLSMask:
        case MCSDataTypeHLSPlaylist:
        case MCSDataTypeHLSAESKey:
        case MCSDataTypeHLSTs:
        case MCSDataTypeHLS:
        case MCSDataTypeFILEMask:
            /* return */
            return nil;
        case MCSDataTypeFILE:
            break;
    }
    NSString *pathExtension = response.pathExtension;
    NSString *contentType = response.contentType;
    NSUInteger totalLength = response.totalLength;
    NSUInteger offset = response.range.location;
    __block id<MCSAssetContent>content = nil;
    __block BOOL isUpdated = NO;
    mcs_queue_sync(^{
        if ( _totalLength != totalLength || ![_pathExtension isEqualToString:pathExtension] || ![_contentType isEqualToString:contentType] ) {
            _totalLength = totalLength;
            _pathExtension = pathExtension;
            _contentType = contentType;
            isUpdated = YES;
        }
        
        content = [mProvider createContentAtOffset:offset pathExtension:_pathExtension];
        [content readwriteRetain];
        if ( content != nil ) [mNodeList bringContentToNode:content];
    });
    
    if ( isUpdated )
        [NSNotificationCenter.defaultCenter postNotificationName:MCSAssetMetadataDidLoadNotification object:self];
    return content;
}

- (void)readwriteCountDidChange:(NSInteger)count {
    if ( count == 0 )
        [self _mergeContents];
}

// 合并文件
- (void)_mergeContents {
    if ( self.readwriteCount != 0 ) return;
    if ( _isStored ) return;
//    if ( mContents.count < 2 ) {
//        _isStored = mContents.count == 1 && mContents.lastObject.length == _totalLength;
//        return;
//    }
//
//    NSMutableArray<id<MCSAssetContent>> *contents = [mContents mutableCopy];
//    NSMutableArray<id<MCSAssetContent>> *deletes = NSMutableArray.alloc.init;
//    [contents sortUsingComparator:^NSComparisonResult(id<MCSAssetContent>obj1, id<MCSAssetContent>obj2) {
//        NSRange range1 = NSMakeRange(obj1.startPositionInAsset, obj1.length);
//        NSRange range2 = NSMakeRange(obj2.startPositionInAsset, obj2.length);
//
//        // 1 包含 2
//        if ( MCSNSRangeContains(range1, range2) ) {
//            if ( ![deletes containsObject:obj2] ) [deletes addObject:obj2];
//        }
//        // 2 包含 1
//        else if ( MCSNSRangeContains(range2, range1) ) {
//            if ( ![deletes containsObject:obj1] ) [deletes addObject:obj1];;
//        }
//
//        return [@(range1.location) compare:@(range2.location)];
//    }];
//
//    if ( deletes.count != 0 ) [contents removeObjectsInArray:deletes];
//
//    // merge
//    UInt64 capacity = 1 * 1024 * 1024;
//    for ( NSInteger i = 0 ; i < contents.count - 1; i += 2 ) {
//        id<MCSAssetContent>write = contents[i];
//        id<MCSAssetContent>read  = contents[i + 1];
//
//        NSUInteger maxPosition1 = write.startPositionInAsset + write.length;
//        NSUInteger maxPosition2 = read.startPositionInAsset + read.length;
//        NSRange readRange = NSMakeRange(0, 0);
//        if ( maxPosition1 >= read.startPositionInAsset && maxPosition1 < maxPosition2 ) // 有交集
//            readRange = NSMakeRange(maxPosition1, maxPosition2 - maxPosition1); // 读取read中未相交的部分
//
//        if ( readRange.length != 0 ) {
//            [write readwriteRetain];
//            [read readwriteRetain];
//            NSError *error = nil;
//            UInt64 positon = readRange.location;
//            while ( true ) { @autoreleasepool {
//                NSData *data = [read readDataAtPosition:positon capacity:capacity error:&error];
//                if ( error != nil || data.length == 0 )
//                    break;
//                if ( ![write writeData:data error:&error] )
//                    break;
//                positon += data.length;
//                if ( positon == NSMaxRange(readRange) ) break;
//            }}
//            [read readwriteRelease];
//            [write readwriteRelease];
//            [read closeRead];
//            [write closeWrite];
//            if ( error == nil ) {
//                [deletes addObject:read];
//            }
//        }
//    }
//
//    if ( deletes.count != 0 ) {
//        for ( id<MCSAssetContent>content in deletes ) { [mProvider removeContent:content]; }
//        [mContents removeObjectsInArray:deletes];
//    }
//
//    _isStored = mContents.count == 1 && mContents.lastObject.length == _totalLength;
}

// 拆分重组内容. 将内容按指定字节拆分重组
- (void)_restructureContents {
    if ( _isStored ) return;
    NSInteger countOfBytesContentUnit = 1 * 1024 * 1024;
 
    // 同一段位置可能存在多个文件
}
@end
