//
//  LocalFileAssetReader.m
//  SJMediaCacheServer
//
//  Created by db on 2025/4/17.
//

#import "LocalFileAssetReader.h"
#import "MCSLogger.h"
#import "MCSUtils.h"
#import "LocalFileAsset.h"
#import "MCSAssetContentReader.h"
#import "MCSError.h"
#import "MCSResponse.h"

@interface LocalFileAssetReader ()<MCSAssetContentReaderDelegate>

@end

@implementation LocalFileAssetReader {
    LocalFileAsset *mAsset;
    MCSRequest *mRequest;
    NSURLRequest *mOriginalRequest;
    float mNetworkTaskPriority;
    __weak id<MCSAssetReaderDelegate> mDelegate;
    NSData *(^mReadDataDecryptor)(NSURLRequest *request, NSUInteger offset, NSData *data);
    MCSReaderStatus mStatus;
    NSHashTable<id<MCSAssetReaderObserver>> *mObservers;
    
    id<MCSAssetContentReader> mContentReader;
    id<MCSResponse> mResponse;
}

- (instancetype)initWithAsset:(LocalFileAsset *)asset request:(MCSRequest *)request networkTaskPriority:(float)networkTaskPriority readDataDecryptor:(NSData *(^_Nullable)(NSURLRequest *request, NSUInteger offset, NSData *data))readDataDecryptor delegate:(id<MCSAssetReaderDelegate>)delegate {
    self = [super init];
    mAsset = asset;
    mRequest = request;
    mOriginalRequest = request.restoreOriginalRequest;
    mNetworkTaskPriority = networkTaskPriority;
    mReadDataDecryptor = readDataDecryptor;
    mDelegate = delegate;
    [mAsset readwriteRetain];
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

- (id<MCSResponse>)response {
    @synchronized (self) {
        return mResponse;
    }
}
 
- (NSUInteger)availableLength {
    @synchronized (self) {
        return mContentReader ? mContentReader.range.length : 0;
    }
}
 
- (NSUInteger)offset {
    @synchronized (self) {
        return mContentReader ? mContentReader.offset : 0;
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

- (MCSDataType)contentDataType {
    return MCSDataTypeLocalFile;
}

- (NSData * _Nonnull (^)(NSURLRequest * _Nonnull, NSUInteger, NSData * _Nonnull))readDataDecryptor {
    return mReadDataDecryptor;
}

#pragma mark - mark

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
                
                id<MCSAssetContent> content = [mAsset getContentWithRequest:mRequest];
                NSUInteger totalLength = content.length;
                MCSRequestContentRange requestRange = MCSRequestGetContentRange(mRequest.proxyRequest.mcs_headers);
                NSRange range = NSMakeRange(0, 0);
                // 200
                if      ( requestRange.start == NSNotFound && requestRange.end == NSNotFound ) {
                    range = NSMakeRange(0, totalLength);
                }
                // bytes=100-500
                else if ( requestRange.start != NSNotFound && requestRange.end != NSNotFound ) {
                    NSUInteger location = requestRange.start;
                    NSUInteger length = (totalLength > requestRange.end ? (requestRange.end + 1) : totalLength) - location;
                    range = NSMakeRange(location, length);
                }
                // bytes=-500
                else if ( requestRange.start == NSNotFound && requestRange.end != NSNotFound ) {
                    NSUInteger length = totalLength > requestRange.end ? (requestRange.end + 1) : 0;
                    NSUInteger location = totalLength - length;
                    range = NSMakeRange(location, length);
                }
                // bytes=500-
                else if ( requestRange.start != NSNotFound && requestRange.end == NSNotFound ) {
                    NSUInteger location = requestRange.start;
                    NSUInteger length = totalLength > location ? (totalLength - location) : 0;
                    range = NSMakeRange(location, length);
                }
                
                if ( range.length == 0 ) {
                    [self _abortWithError:[NSError mcs_errorWithCode:MCSInvalidRequestError userInfo:@{
                        MCSErrorUserInfoObjectKey : mRequest,
                        MCSErrorUserInfoReasonKey : @"请求range参数错误!"
                    }]];
                    return;
                }
                mContentReader = [MCSAssetFileContentReader.alloc initWithAsset:mAsset fileContent:content rangeInAsset:range delegate:self];
                [mContentReader prepare];
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
                data = [mContentReader readDataOfLength:length];
                if ( data == nil || data.length == 0 ) return nil;
                NSUInteger readLength = data.length;
                if ( mReadDataDecryptor != nil ) {
                    NSData *decrypted = mReadDataDecryptor(mOriginalRequest, mContentReader.offset - readLength, data);
                    NSAssert(decrypted.length == data.length, @"Decrypted data length must equal input data length");
                    data = decrypted;
                }
                
                if ( mContentReader.status == MCSReaderStatusFinished ) {
                    [self _finish];
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
                BOOL result = [mContentReader seekToOffset:offset];
                if ( result && mContentReader.status == MCSReaderStatusFinished ) {
                    [self _finish];
                }
                return result;
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

#pragma mark - mark

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
            [self _clear];
            mStatus = MCSReaderStatusFinished;
            MCSAssetReaderDebugLog(@"%@: <%p>.finished;\n", NSStringFromClass(self.class), self);
            [self _notifyObserversWithStatus:MCSReaderStatusFinished];
        }
            break;
    }
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
            [self _clear];
            [mDelegate reader:self didAbortWithError:error];
            MCSAssetReaderDebugLog(@"%@: <%p>.abort { error: %@ };\n", NSStringFromClass(self.class), self, error);
            [self _notifyObserversWithStatus:MCSReaderStatusAborted];
        }
            break;
    }
}

/// 清理
///
/// unlocked
- (void)_clear {

    [mContentReader abortWithError:nil];
    mContentReader = nil;
    
    [mAsset readwriteRelease];
    
    MCSAssetReaderDebugLog(@"%@: <%p>.clear;\n", NSStringFromClass(self.class), self);
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
                NSRange range = reader.range;
                mResponse = [MCSResponse.alloc initWithTotalLength:reader.content.length range:range contentType:reader.content.mimeType];
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

- (void)reader:(id<MCSAssetContentReader>)reader didAbortWithError:(nullable NSError *)error {
    [self abortWithError:error];
}
@end
