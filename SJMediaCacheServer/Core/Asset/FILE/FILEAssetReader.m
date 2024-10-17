//
//  FILEAssetReader.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "FILEAssetReader.h"
#import "FILEAsset.h"
#import "MCSError.h"
#import "MCSLogger.h"
#import "MCSQueue.h"
#import "MCSResponse.h"
#import "MCSConsts.h"
#import "MCSUtils.h"
#import "MCSAssetContentReader.h"

@interface FILEAssetReader ()<MCSAssetContentReaderDelegate> {
    NSHashTable<id<MCSAssetReaderObserver>> *mObservers;
    MCSReaderStatus mStatus;
    FILEAsset *mAsset;
    NSURLRequest *mRequest;
    NSArray<id<MCSAssetContentReader>> *_Nullable mContentReaders;
    NSInteger mCurrentReaderIndex;
    UInt64 mReadLength;
    id<MCSResponse> mResponse;
    __weak id<MCSAssetReaderDelegate> mDelegate;
    NSData *(^mReadDataDecoder)(NSURLRequest *request, NSUInteger offset, NSData *data);
    float mNetworkTaskPriority;
    NSRange mFixedRange;
}
 
@property (nonatomic, readonly, nullable) id<MCSAssetContentReader> currentReader;
@end

@implementation FILEAssetReader
- (instancetype)initWithAsset:(FILEAsset *)asset request:(MCSRequest *)request networkTaskPriority:(float)networkTaskPriority readDataDecoder:(NSData *(^_Nullable)(NSURLRequest *request, NSUInteger offset, NSData *data))readDataDecoder delegate:(id<MCSAssetReaderDelegate>)delegate {
    self = [super init];
    if ( self ) {
        mAsset = asset;
        mRequest = [request restoreOriginalURLRequest];
        mDelegate = delegate;
        mNetworkTaskPriority = networkTaskPriority;
        mReadDataDecoder = readDataDecoder;
        mCurrentReaderIndex = NSNotFound;
        mFixedRange = MCSNSRangeUndefined;
        [mAsset readwriteRetain];
        
#ifdef DEBUG
        MCSAssetReaderDebugLog(@"%@: <%p>.init { URL: %@, asset: %@, headers: %@ };\n", NSStringFromClass(self.class), self, mRequest.URL, asset, mRequest.allHTTPHeaderFields);
#endif
    }
    return self;
}

- (void)dealloc {
    mDelegate = nil;
    [mObservers removeAllObjects];
    [self _abortWithError:nil];
    MCSAssetReaderDebugLog(@"%@: <%p>.dealloc;\n", NSStringFromClass(self.class), self);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { request: %@\n };", NSStringFromClass(self.class), self, mRequest];
}

- (void)prepare {
    @synchronized (self) {
        switch ( mStatus ) {
            case MCSReaderStatusPreparing:
            case MCSReaderStatusFinished:
            case MCSReaderStatusAborted:
            case MCSReaderStatusReadyToRead:
                /* return */
                return;
            case MCSReaderStatusUnknown: {
                mStatus = MCSReaderStatusPreparing;
                MCSAssetReaderDebugLog(@"%@: <%p>.prepare { asset: %@ };\n", NSStringFromClass(self.class), self, mAsset.name);
                [self _notifyObserversWithStatus:MCSReaderStatusPreparing];
                [self _prepare];
            }
                break;
        }
    }
}

- (nullable NSData *)readDataOfLength:(NSUInteger)length {
    NSData *data = nil;
    @synchronized (self) {
        switch ( mStatus ) {
            case MCSReaderStatusUnknown:
            case MCSReaderStatusPreparing:
            case MCSReaderStatusFinished:
            case MCSReaderStatusAborted:
                /* return */
                return nil;
            case MCSReaderStatusReadyToRead: {
                id<MCSAssetContentReader> currentReader = self.currentReader;
                if ( currentReader.status == MCSReaderStatusReadyToRead ) {
                    data = [currentReader readDataOfLength:length];
                    if ( data == nil || data.length == 0 ) return nil;
                    NSUInteger readLength = data.length;
                    if ( mReadDataDecoder != nil ) data = mReadDataDecoder(mRequest, mContentReaders.firstObject.range.location + mReadLength, data);
                    mReadLength += readLength;
                }
                
                if ( currentReader.status == MCSReaderStatusFinished ) {
                    [self _prepareNextContentReader];
                }
            }
                break;
        }
    }
    return data;
}

- (BOOL)seekToOffset:(NSUInteger)offset {
    @synchronized (self) {
        switch ( mStatus ) {
            case MCSReaderStatusUnknown:
            case MCSReaderStatusPreparing:
            case MCSReaderStatusFinished:
            case MCSReaderStatusAborted:
                /* return */
                return NO;
            case MCSReaderStatusReadyToRead: {
                for ( NSInteger i = 0 ; i < mContentReaders.count ; ++ i ) {
                    id<MCSAssetContentReader> contentReader = mContentReaders[i];
                    if ( NSLocationInRange(offset - 1, contentReader.range) ) {
                        mCurrentReaderIndex = i;
                        BOOL result = [contentReader seekToOffset:offset];
                        if ( result ) {
                            mReadLength = offset - mResponse.range.location;
                            
                            if ( contentReader.status == MCSReaderStatusFinished ) {
                                [self _prepareNextContentReader];
                            }
                        }
                        return result;
                    }
                }
                return NO;
            }
        }
    }
}

- (void)abortWithError:(nullable NSError *)error {
    @synchronized (self) {
        [self _abortWithError:error];
    }
}

- (void)registerObserver:(id<MCSAssetReaderObserver>)observer {
    if ( observer != nil ) {
        @synchronized (self) {
            if ( mObservers == nil ) {
                mObservers = NSHashTable.weakObjectsHashTable;
            }
            [mObservers addObject:observer];
        }
    }
}

- (void)removeObserver:(id<MCSAssetReaderObserver>)observer {
    @synchronized (self) {
        [mObservers removeObject:observer];
    }
}

#pragma mark -

- (id<MCSResponse>)response {
    @synchronized (self) {
        return mResponse;
    }
}
 
- (NSUInteger)availableLength {
    @synchronized (self) {
        id<MCSAssetContentReader> currentReader = self.currentReader;
        NSUInteger availableLength = currentReader.range.location + currentReader.availableLength;
        return availableLength;
    }
}
 
- (NSUInteger)offset {
    @synchronized (self) {
        NSUInteger offset = mResponse.range.location + mReadLength;
        return offset;
    }
}

- (MCSReaderStatus)status {
    @synchronized (self) {
        return mStatus;
    }
}

- (id<MCSAsset>)asset {
    return mAsset;
}

- (float)networkTaskPriority {
    return mNetworkTaskPriority;
}

- (nullable id<MCSAssetReaderDelegate>)delegate {
    return mDelegate;
}


#pragma mark - unlocked

/// 创建 content readers
///
/// unlocked
- (void)_prepare {
    NSUInteger totalLength = mAsset.totalLength;
    if ( totalLength == 0 ) {
        // create single sub reader to load asset total length
        NSURL *URL = mRequest.URL;
        NSMutableURLRequest *request = [mRequest mcs_requestWithRedirectURL:URL];
        mContentReaders = @[
            [MCSAssetHTTPContentReader.alloc initWithAsset:mAsset request:request networkTaskPriority:mNetworkTaskPriority dataType:MCSDataTypeFILE delegate:self]
        ];
    }
    else {
        MCSRequestContentRange requestRange = MCSRequestGetContentRange(mRequest.mcs_headers);
        NSRange fixed = NSMakeRange(0, 0);
        // 200
        if      ( requestRange.start == NSNotFound && requestRange.end == NSNotFound ) {
            fixed = NSMakeRange(0, totalLength);
        }
        // bytes=100-500
        else if ( requestRange.start != NSNotFound && requestRange.end != NSNotFound ) {
            NSUInteger location = requestRange.start;
            NSUInteger length = (totalLength > requestRange.end ? (requestRange.end + 1) : totalLength) - location;
            fixed = NSMakeRange(location, length);
        }
        // bytes=-500
        else if ( requestRange.start == NSNotFound && requestRange.end != NSNotFound ) {
            NSUInteger length = totalLength > requestRange.end ? (requestRange.end + 1) : 0;
            NSUInteger location = totalLength - length;
            fixed = NSMakeRange(location, length);
        }
        // bytes=500-
        else if ( requestRange.start != NSNotFound && requestRange.end == NSNotFound ) {
            NSUInteger location = requestRange.start;
            NSUInteger length = totalLength > location ? (totalLength - location) : 0;
            fixed = NSMakeRange(location, length);
        }
        
        if ( fixed.length == 0 ) {
            [self _abortWithError:[NSError mcs_errorWithCode:MCSInvalidRequestError userInfo:@{
                MCSErrorUserInfoObjectKey : mRequest,
                MCSErrorUserInfoReasonKey : @"请求range参数错误!"
            }]];
            return;
        }
        
        __block NSRange curr = fixed;
        NSMutableArray<id<MCSAssetContentReader>> *contentReaders = NSMutableArray.array;
        [mAsset enumerateContentNodesUsingBlock:^(MCSAssetContentNode * _Nonnull node, BOOL * _Nonnull stop) {
            id<MCSAssetContent> content = node.longestContent;
            NSRange available = NSMakeRange(content.startPositionInAsset, content.length);
            NSRange intersection = NSIntersectionRange(curr, available);
            if ( intersection.length != 0 ) {
                // undownloaded part
                NSRange leftRange = NSMakeRange(curr.location, intersection.location - curr.location);
                if ( leftRange.length != 0 ) {
                    MCSAssetHTTPContentReader *reader = [self _HTTPContentReaderWithRange:leftRange];
                    [contentReaders addObject:reader];
                }
                
                // downloaded part
                NSRange matchedRange = NSMakeRange(NSMaxRange(leftRange), intersection.length);
                MCSAssetFileContentReader *reader = [MCSAssetFileContentReader.alloc initWithAsset:mAsset fileContent:content rangeInAsset:matchedRange delegate:self];
                [contentReaders addObject:reader];
                
                // next part
                curr = NSMakeRange(NSMaxRange(intersection), NSMaxRange(fixed) - NSMaxRange(intersection));
            }
            
            // stop
            if ( curr.length == 0 || available.location > NSMaxRange(curr) ) {
                *stop = YES;
            }
        }];
        
        if ( curr.length != 0 ) {
            // undownloaded part
            MCSAssetHTTPContentReader *reader = [self _HTTPContentReaderWithRange:curr];
            [contentReaders addObject:reader];
        }
         
        mContentReaders = contentReaders.copy;
        mFixedRange = fixed;
    }
     
    MCSAssetReaderDebugLog(@"%@: <%p>.createSubreaders { count: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)mContentReaders.count);

    [self _prepareNextContentReader];
}

/// 准备下一个 content reader
///
/// unlocked
- (void)_prepareNextContentReader {
    if ( self.currentReader == mContentReaders.lastObject ) {
        [self _finish];
        return;
    }
    
    if ( mCurrentReaderIndex == NSNotFound )
        mCurrentReaderIndex = 0;
    else
        mCurrentReaderIndex += 1;
    
    MCSAssetReaderDebugLog(@"%@: <%p>.subreader.prepare { index: %ld, sub: %@, count: %lu };\n", NSStringFromClass(self.class), self, (long)mCurrentReaderIndex, self.currentReader, (unsigned long)mContentReaders.count);

    [self.currentReader prepare];
}

/// 获取当前的 content reader
///
/// unlocked
- (nullable id<MCSAssetContentReader>)currentReader {
    if ( mCurrentReaderIndex != NSNotFound && mCurrentReaderIndex < mContentReaders.count ) {
        return mContentReaders[mCurrentReaderIndex];
    }
    return nil;
}

/// 出错中止
///
/// unlocked
- (void)_abortWithError:(nullable NSError *)error {
    switch ( mStatus ) {
        case MCSReaderStatusFinished:
        case MCSReaderStatusAborted:
            /* return */
            return;
        case MCSReaderStatusUnknown:
        case MCSReaderStatusPreparing:
        case MCSReaderStatusReadyToRead: {
            mStatus = MCSReaderStatusAborted;
            [self _clean];
            [mDelegate reader:self didAbortWithError:error];
            MCSAssetReaderDebugLog(@"%@: <%p>.abort { error: %@ };\n", NSStringFromClass(self.class), self, error);
            [self _notifyObserversWithStatus:MCSReaderStatusAborted];
        }
            break;
    }
}

/// 读取完成
///
/// unlocked
- (void)_finish {
    switch ( mStatus ) {
        case MCSReaderStatusFinished:
        case MCSReaderStatusAborted:
            /* return */
            return;
        case MCSReaderStatusUnknown:
        case MCSReaderStatusPreparing:
        case MCSReaderStatusReadyToRead: {
            [self _clean];
            mStatus = MCSReaderStatusFinished;
            MCSAssetReaderDebugLog(@"%@: <%p>.finished;\n", NSStringFromClass(self.class), self);
            [self _notifyObserversWithStatus:MCSReaderStatusFinished];
        }
            break;
    }
}

/// 清理
///
/// unlocked
- (void)_clean {
    [mContentReaders makeObjectsPerformSelector:@selector(abortWithError:) withObject:nil];
    mContentReaders = nil;

    [mAsset readwriteRelease];
    
    MCSAssetReaderDebugLog(@"%@: <%p>.clean;\n", NSStringFromClass(self.class), self);
}

/// 通知
///
/// unlocked
- (void)_notifyObserversWithStatus:(MCSReaderStatus)status {
    for ( id<MCSAssetReaderObserver> observer in MCSAllHashTableObjects(mObservers) ) {
        if ( [observer respondsToSelector:@selector(reader:statusDidChange:)] ) {
            [observer reader:self statusDidChange:mStatus];
        }
    }
}
  
#pragma mark - MCSAssetContentReaderDelegate

- (void)readerWasReadyToRead:(id<MCSAssetContentReader>)reader {
    @synchronized (self) {
        switch ( mStatus ) {
            default:break;
                // first reader
            case MCSReaderStatusPreparing: {
                id<MCSAssetContentReader> first = reader;
                NSRange range = mContentReaders.count == 1 ? first.range : mFixedRange;
                mResponse = [MCSResponse.alloc initWithTotalLength:mAsset.totalLength range:range contentType:reader.content.mimeType];
                mStatus = MCSReaderStatusReadyToRead;
                [mDelegate reader:self didReceiveResponse:mResponse];
                [self _notifyObserversWithStatus:MCSReaderStatusReadyToRead];
            }
                break;
        }
    }
}

- (void)reader:(id<MCSAssetContentReader>)reader hasAvailableDataWithLength:(NSUInteger)length {
    [mDelegate reader:self hasAvailableDataWithLength:length];
}

- (void)reader:(id<MCSAssetContentReader>)reader didAbortWithError:(NSError *)error {
    [self abortWithError:error];
}

- (MCSAssetHTTPContentReader *)_HTTPContentReaderWithRange:(NSRange)range {
    NSMutableURLRequest *request = [mRequest mcs_requestWithRange:range];
    return [MCSAssetHTTPContentReader.alloc initWithAsset:mAsset request:request networkTaskPriority:mNetworkTaskPriority dataType:MCSDataTypeFILE delegate:self];
}
@end
