//
//  HLSAssetReader.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "HLSAssetReader.h"
#import "HLSAssetContentReader.h"
#import "MCSLogger.h"
#import "HLSAsset.h"
#import "MCSError.h"
#import "MCSResponse.h"
#import "MCSConsts.h"
#import "MCSUtils.h"
#import "MCSURL.h"

@interface HLSAssetReader ()<MCSAssetContentReaderDelegate, MCSAssetObserver> {
    MCSDataType mDataType;
    MCSReaderStatus mStatus;
    NSURLRequest *mRequest;
    HLSAsset *mAsset;
    id<MCSAssetContentReader> mReader;
    NSHashTable<id<MCSAssetReaderObserver>> *mObservers;
    UInt64 mOffset;
}
@end

@implementation HLSAssetReader
@synthesize readDataDecryptor = _readDataDecryptor;
@synthesize response = _response;

- (instancetype)initWithAsset:(__weak HLSAsset *)asset request:(MCSRequest *)request networkTaskPriority:(float)networkTaskPriority readDataDecryptor:(NSData *(^_Nullable)(NSURLRequest *request, NSUInteger offset, NSData *data))readDataDecryptor delegate:(id<MCSAssetReaderDelegate>)delegate {
    self = [super init];
    if ( self ) {
        mAsset = asset;
        mRequest = [request restoreOriginalRequest];
        mDataType = [MCSURL.shared dataTypeForHLSProxyURL:request.proxyRequest.URL];
        _networkTaskPriority = networkTaskPriority;
        _readDataDecryptor = readDataDecryptor;
        _delegate = delegate;
        [mAsset readwriteRetain];
        [mAsset registerObserver:self];
        
        MCSAssetReaderDebugLog(@"%@: <%p>.init { URL: %@, asset: %@, headers: %@ };\n", NSStringFromClass(self.class), self, mRequest.URL, asset, mRequest.allHTTPHeaderFields);
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { request: %@\n };", NSStringFromClass(self.class), self, mRequest.mcs_description];
}

- (void)dealloc {
    _delegate = nil;
    [mObservers removeAllObjects];
    [self _abortWithError:nil];
    MCSAssetReaderDebugLog(@"%@: <%p>.dealloc;\n", NSStringFromClass(self.class), self);
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
            case MCSReaderStatusUnknown:
                break;
        }
        
        mStatus = MCSReaderStatusPreparing;
        MCSAssetReaderDebugLog(@"%@: <%p>.prepare { asset: %@, request: %@ };\n", NSStringFromClass(self.class), self, mAsset.name, mRequest);
        [self _notifyObserversWithStatus:mStatus];

        switch ( mDataType ) {
            case MCSDataTypeHLSPlaylist: {
                mReader = [HLSAssetPlaylistContentReader.alloc initWithAsset:mAsset request:mRequest networkTaskPriority:_networkTaskPriority delegate:self];
            }
                break;
            case MCSDataTypeHLSAESKey: {
                mReader = [HLSAssetKeyContentReader.alloc initWithAsset:mAsset request:mRequest networkTaskPriority:_networkTaskPriority delegate:self];
            }
                break;
            case MCSDataTypeHLSSegment: {
                NSRange byteRange = MCSRequestRange(MCSRequestGetContentRange(mRequest.allHTTPHeaderFields));
                id<HLSAssetSegment> content = [mAsset getSegmentContentWithOriginalURL:mRequest.URL byteRange:byteRange];
                if      ( content == nil ) {
                    mReader = [MCSAssetHTTPContentReader.alloc initWithAsset:mAsset request:mRequest networkTaskPriority:_networkTaskPriority dataType:MCSDataTypeHLSSegment delegate:self];
                }
                // is full
                else if ( content.length == content.totalLength) {
                    mReader = [MCSAssetFileContentReader.alloc initWithAsset:mAsset fileContent:content rangeInAsset:content.byteRange delegate:self];
                }
                // is partial
                else {
                    mReader = [MCSAssetHTTPContentReader.alloc initWithAsset:mAsset request:mRequest rangeInAsset:content.byteRange contentReadwrite:content networkTaskPriority:_networkTaskPriority dataType:MCSDataTypeHLSSegment delegate:self];
                }
            }
                break;
            case MCSDataTypeHLSSubtitles: {
                mReader = [HLSAssetSubtitlesContentReader.alloc initWithAsset:mAsset request:mRequest networkTaskPriority:_networkTaskPriority delegate:self];
            }
                break;
            case MCSDataTypeHLSInit: {
                
            }
                break;
            default: {
                [self _abortWithError:[NSError mcs_errorWithCode:MCSFileError userInfo:@{
                    MCSErrorUserInfoObjectKey : mRequest,
                    MCSErrorUserInfoReasonKey : [NSString stringWithFormat:@"Unsupported request data type %ld", mDataType]
                }]];
            }
                return;
        }
        [mReader prepare];
    }
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    @synchronized (self) {
        @try {
            switch ( mStatus ) {
                case MCSReaderStatusUnknown:
                case MCSReaderStatusPreparing:
                case MCSReaderStatusFinished:
                case MCSReaderStatusAborted:
                    return nil; /* return nil; */
                case MCSReaderStatusReadyToRead: {
                    NSData *data = nil;
                    NSUInteger position = mReader.offset;
                    data = [mReader readDataOfLength:length];
                    mOffset = mReader.offset;
                    if ( data != nil && _readDataDecryptor != nil ) {
                        NSData *decrypted = _readDataDecryptor(mRequest, position, data);
                        NSAssert(decrypted.length == data.length, @"Decrypted data length must equal input data length");
                        data = decrypted;
                    }
                    return data;
                }
            }
        }
        @finally {
            if ( mReader.status == MCSReaderStatusFinished ) {
                [self _finish];
            }
        }
    }
}

- (BOOL)seekToOffset:(NSUInteger)offset {
    @synchronized (self) {
        @try {
            BOOL result = NO;
            switch ( mStatus ) {
                case MCSReaderStatusUnknown:
                case MCSReaderStatusPreparing:
                case MCSReaderStatusFinished:
                case MCSReaderStatusAborted:
                    return NO; /* return NO; */
                case MCSReaderStatusReadyToRead: {
                    result = [mReader seekToOffset:offset];
                    mOffset = mReader.offset;
                }
                    break;
            }
            return result;
        } @finally {
            if ( mReader.status == MCSReaderStatusFinished ) {
                [self _finish];
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
    if ( observer != nil ) {
        @synchronized (self) {
            [mObservers removeObject:observer];
        }
    }
}

#pragma mark -

- (id<MCSResponse>)response {
    @synchronized (self) {
        return _response;
    }
}
 
- (NSUInteger)availableLength {
    @synchronized (self) {
        return mReader.availableLength;
    }
}

- (NSUInteger)offset {
    @synchronized (self) {
        return mOffset;
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

- (MCSDataType)contentDataType {
    return mDataType;
}

#pragma mark - unlocked

- (void)_abortWithError:(nullable NSError *)error {
    switch ( mStatus ) {
        case MCSReaderStatusFinished:
        case MCSReaderStatusAborted:
            return; /* return */
        case MCSReaderStatusUnknown:
        case MCSReaderStatusPreparing:
        case MCSReaderStatusReadyToRead: {
            mStatus = MCSReaderStatusAborted;
            [self _clear];
            [_delegate reader:self didAbortWithError:error];
            MCSAssetReaderDebugLog(@"%@: <%p>.abort { error: %@ };\n", NSStringFromClass(self.class), self, error);
            [self _notifyObserversWithStatus:mStatus];
        }
            break;
    }
}

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
            [self _notifyObserversWithStatus:mStatus];
        }
            break;
    }
}

- (void)_clear {
    [mReader abortWithError:nil];
    mReader = nil;
    [mAsset readwriteRelease];
    
    MCSAssetReaderDebugLog(@"%@: <%p>.clear;\n", NSStringFromClass(self.class), self);
}

- (void)_notifyObserversWithStatus:(MCSReaderStatus)status {
    for ( id<MCSAssetReaderObserver> observer in MCSAllHashTableObjects(mObservers) ) {
        if ( [observer respondsToSelector:@selector(reader:statusDidChange:)] ) {
            [observer reader:self statusDidChange:mStatus];
        }
    }
}

#pragma mark - MCSAssetObserver

- (void)assetWillClear:(id<MCSAsset>)asset {
    @synchronized (self) {
        [self abortWithError:[NSError mcs_errorWithCode:MCSAbortError userInfo:@{
            MCSErrorUserInfoObjectKey : asset,
            MCSErrorUserInfoReasonKey : @"Unable to continue reading the asset because it is about to be cleared."
        }]];
    }
}

#pragma mark - MCSAssetContentReaderDelegate

- (void)readerWasReadyToRead:(id<MCSAssetContentReader>)reader {
    @synchronized (self) {
        switch ( mStatus ) {
            case MCSReaderStatusUnknown:
            case MCSReaderStatusReadyToRead:
            case MCSReaderStatusFinished:
            case MCSReaderStatusAborted:
                return; /** return; */
            case MCSReaderStatusPreparing: {
                mStatus = MCSReaderStatusReadyToRead;
                mOffset = reader.offset;
                switch ( mDataType ) {
                    case MCSDataTypeHLSSegment: {
                        id<HLSAssetSegment> content = reader.content;
                        _response = [MCSResponse.alloc initWithTotalLength:content.totalLength range:reader.range contentType:content.mimeType];
                    }
                        break;
                    case MCSDataTypeHLSMask:
                    case MCSDataTypeHLSPlaylist:
                    case MCSDataTypeHLSAESKey:
                    case MCSDataTypeHLSSubtitles:
                    case MCSDataTypeHLSInit:
                    case MCSDataTypeHLS:
                    case MCSDataTypeFILEMask:
                    case MCSDataTypeFILE:
                        _response = [MCSResponse.alloc initWithTotalLength:reader.range.length];
                        break;
                }
                [self _notifyObserversWithStatus:mStatus];
            }
                break;
        }
    }
    [_delegate reader:self didReceiveResponse:_response];
}

- (void)reader:(id<MCSAssetContentReader>)reader hasAvailableDataWithLength:(NSUInteger)length {
    [_delegate reader:self hasAvailableDataWithLength:length];
}

- (void)reader:(id<MCSAssetContentReader>)reader didAbortWithError:(nullable NSError *)error {
    @synchronized (self) {
        [self _abortWithError:error];
    }
}
@end
