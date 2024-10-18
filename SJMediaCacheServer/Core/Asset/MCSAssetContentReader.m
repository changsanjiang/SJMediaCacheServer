//
//  MCSAssetContentReader.m
//  SJMediaCacheServer
//
//  Created by 畅三江 on 2021/7/19.
//

#import "MCSAssetContentReader.h"
#import "MCSError.h"
#import "MCSLogger.h"
#import "NSFileHandle+MCS.h"
#import "MCSUtils.h"

@interface MCSAssetContentReader()<MCSAssetContentObserver> {
    MCSReaderStatus _mStatus;
    id<MCSAsset> _mAsset;
    id<MCSAssetContent> _Nullable _mContent;
    NSRange _mRange;
    UInt64 _mAvailableLength;
    UInt64 _mReadLength;
}
@end

@implementation MCSAssetContentReader
@synthesize delegate = _delegate;
- (instancetype)initWithAsset:(id<MCSAsset>)asset delegate:(id<MCSAssetContentReaderDelegate>)delegate {
    self = [super init];
    if ( self ) {
        _mAsset = asset;
        _delegate = delegate; 
    }
    return self;
}

- (void)dealloc {
    _delegate = nil;
    [self _abortWithError:nil];
    MCSContentReaderDebugLog(@"%@: <%p>.dealloc;\n", NSStringFromClass(self.class), self);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { range: %@\n };", NSStringFromClass(self.class), self, NSStringFromRange(_mRange)];
}

- (nullable __kindof id<MCSAssetContent>)content {
    @synchronized (self) {
        return _mContent;
    }
}

- (void)prepare {
    @synchronized (self) {
        switch ( _mStatus ) {
            case MCSReaderStatusReadyToRead:
            case MCSReaderStatusPreparing:
            case MCSReaderStatusFinished:
            case MCSReaderStatusAborted:
                /* return */
                return;
            case MCSReaderStatusUnknown: {
                _mStatus = MCSReaderStatusPreparing;
                [self prepareContent];
            }
                break;
        }
    }
}

- (nullable NSData *)readDataOfLength:(UInt64)lengthParam {
    NSError *error = nil;
    NSData *data = nil;
    @try {
        @synchronized (self) {
            switch ( _mStatus ) {
                case MCSReaderStatusUnknown:
                case MCSReaderStatusPreparing:
                case MCSReaderStatusFinished:
                case MCSReaderStatusAborted:
                    /* return */
                    return nil;
                case MCSReaderStatusReadyToRead: {
                    UInt64 capacity = MIN(lengthParam, _mAvailableLength - _mReadLength);
                    UInt64 position = _mRange.location + _mReadLength;
                    data = capacity != 0 ? [_mContent readDataAtPosition:position capacity:capacity error:&error] : nil;
                    if ( data == nil || error != nil ) return nil; // return if error & @finally abort
                    
                    UInt64 readLength = data.length;
                    if ( readLength == 0 ) return nil;
                    
                    _mReadLength += readLength;

                    MCSContentReaderDebugLog(@"%@: <%p>.read { range: %@, offset: %llu, length: %llu };\n", NSStringFromClass(self.class), self, NSStringFromRange(_mRange), position, readLength);
                    
                    BOOL isReachedEndPosition = (_mReadLength == _mRange.length);
                    if ( isReachedEndPosition ) {
                        [self _finish];
                    }
                }
                    break;
            }
        }
        return data;
    } @finally {
        if ( error != nil ) {
            [self abortWithError:error];
        }
    }
}

- (BOOL)seekToOffset:(UInt64)offset {
    @synchronized (self) {
        switch ( _mStatus ) {
            case MCSReaderStatusUnknown:
            case MCSReaderStatusPreparing:
            case MCSReaderStatusFinished:
            case MCSReaderStatusAborted:
                /* return */
                return NO;
            case MCSReaderStatusReadyToRead: {
                NSRange range = NSMakeRange(_mRange.location, _mAvailableLength);
                if ( !NSLocationInRange(offset - 1, range) ) return NO;
                
                // offset     = range.location + readLength;
                // readLength = offset - range.location
                UInt64 readLength = offset - _mRange.location;
                if ( readLength != _mReadLength ) {
                    _mReadLength = readLength;
                    BOOL isReachedEndPosition = (_mReadLength == _mRange.length);
                    if ( isReachedEndPosition ) {
                        [self _finish];
                    }
                }
                return YES;
            }
        }
    }
}

- (void)abortWithError:(nullable NSError *)error {
    @synchronized (self) {
        [self _abortWithError:error];
    }
}

#pragma mark -

- (NSRange)range {
    @synchronized (self) {
        return _mRange;
    }
}

- (UInt64)availableLength {
    @synchronized (self) {
        return _mAvailableLength;
    }
}

- (UInt64)offset {
    @synchronized (self) {
        return _mRange.location + _mReadLength;
    }
}

- (MCSReaderStatus)status {
    @synchronized (self) {
        return _mStatus;
    }
}

#pragma mark - subclass callback

- (void)contentDidReady:(id<MCSAssetContent>)content range:(NSRange)range {
    @synchronized (self) {
        switch ( _mStatus ) {
            case MCSReaderStatusFinished:
            case MCSReaderStatusAborted:
            case MCSReaderStatusReadyToRead:
                /* reutrn */
                return;
            case MCSReaderStatusUnknown:
            case MCSReaderStatusPreparing: {
                _mStatus = MCSReaderStatusReadyToRead;
                _mRange = range;
                _mContent = content;
                [_mContent registerObserver:self];
                NSRange contentRange = NSMakeRange(_mContent.startPositionInAsset, (NSInteger)_mContent.length);
                _mAvailableLength = NSIntersectionRange(contentRange, _mRange).length;
                [_delegate readerWasReadyToRead:self];
                if ( _mAvailableLength != 0 && _mReadLength < _mAvailableLength )
                    [_delegate reader:self hasAvailableDataWithLength:(NSInteger)(_mAvailableLength - _mReadLength)];
            }
                break;
        }
    }
}

#pragma mark - MCSAssetContentObserver

- (void)content:(id<MCSAssetContent>)content didWriteDataWithLength:(NSUInteger)length {
    @synchronized (self) {
        NSRange contentRange = NSMakeRange(_mContent.startPositionInAsset, content.length);
        _mAvailableLength = NSIntersectionRange(contentRange, _mRange).length;
    }
    [_delegate reader:self hasAvailableDataWithLength:length];
}

#pragma mark - unlocked

- (void)_abortWithError:(nullable NSError *)error {
    switch ( _mStatus ) {
        case MCSReaderStatusFinished:
        case MCSReaderStatusAborted:
            /* return */
            return;
        case MCSReaderStatusUnknown:
        case MCSReaderStatusPreparing:
        case MCSReaderStatusReadyToRead: {
            _mStatus = MCSReaderStatusAborted;
            [self _clear];
            [self didAbortWithError:error];
            [_delegate reader:self didAbortWithError:error];
            MCSContentReaderDebugLog(@"%@: <%p>.abort { error: %@ };\n", NSStringFromClass(self.class), self, error);
        }
            break;
    }
}

- (void)_finish {
    switch ( _mStatus ) {
        case MCSReaderStatusFinished:
        case MCSReaderStatusAborted:
            /* return */
            return;
        case MCSReaderStatusUnknown:
        case MCSReaderStatusPreparing:
        case MCSReaderStatusReadyToRead: {
            _mStatus = MCSReaderStatusFinished;
            [self _clear];
            MCSContentReaderDebugLog(@"%@: <%p>.finished { range: %@ , file: %@ };\n", NSStringFromClass(self.class), self, NSStringFromRange(_mRange), _mContent);
        }
            break;
    }
}

- (void)_clear {
    [_mContent removeObserver:self];
    [_mContent readwriteRelease];
    [_mContent closeRead];
}

- (void)didAbortWithError:(nullable NSError *)error { }
@end


@implementation MCSAssetFileContentReader {
    id<MCSAssetContent> mFileContent;
    NSRange mReadRange;
}

- (instancetype)initWithAsset:(id<MCSAsset>)asset fileContent:(id<MCSAssetContent>)content rangeInAsset:(NSRange)range delegate:(id<MCSAssetContentReaderDelegate>)delegate {
    self = [super initWithAsset:asset delegate:delegate];
    if ( self ) {
        mFileContent = content;
        mReadRange = range;
        [mFileContent readwriteRetain];
    }
    return self;
}

- (void)dealloc {
    [mFileContent readwriteRelease];
}
 
- (void)prepareContent {
    MCSContentReaderDebugLog(@"%@: <%p>.prepareContent { range: %@, file: %@ };\n", NSStringFromClass(self.class), self, NSStringFromRange(mReadRange), mFileContent);
    
    if ( mReadRange.location < mFileContent.startPositionInAsset || NSMaxRange(mReadRange) > (mFileContent.startPositionInAsset + mFileContent.length) ) {
        [self abortWithError:[NSError mcs_errorWithCode:MCSInvalidParameterError userInfo:@{
            MCSErrorUserInfoObjectKey : self,
            MCSErrorUserInfoReasonKey : @"请求范围错误, 请求范围未在内容范围中!"
        }]];
        return;
    }
    
    [mFileContent readwriteRetain];
    [self contentDidReady:mFileContent range:mReadRange];
}
@end

#import "NSFileHandle+MCS.h"
#import "MCSError.h"
#import "MCSDownload.h"
#import "MCSLogger.h"
#import "MCSUtils.h"
#import "MCSQueue.h"
 
@interface MCSAssetHTTPContentReader ()<MCSDownloadTaskDelegate> {
    id<MCSAsset> mAsset;
    NSURLRequest *mRequest;
    MCSDataType mDataType;
    NSRange mReadRange;
    id<MCSAssetContent>_Nullable mHTTPContent;
    id<MCSDownloadTask>_Nullable mTask;
    float mNetworkTaskPriority;
}
@end

@implementation MCSAssetHTTPContentReader
- (instancetype)initWithAsset:(id<MCSAsset>)asset request:(NSURLRequest *)request networkTaskPriority:(float)priority dataType:(MCSDataType)dataType delegate:(id<MCSAssetContentReaderDelegate>)delegate {
    return [self initWithAsset:asset request:request rangeInAsset:NSMakeRange(0, 0) contentReadwrite:nil networkTaskPriority:priority dataType:dataType delegate:delegate];
}

- (instancetype)initWithAsset:(id<MCSAsset>)asset request:(NSURLRequest *)request rangeInAsset:(NSRange)range contentReadwrite:(nullable id<MCSAssetContent>)content /* 如果content不存在将会通过asset进行创建 */ networkTaskPriority:(float)priority dataType:(MCSDataType)dataType delegate:(id<MCSAssetContentReaderDelegate>)delegate {
    self = [super initWithAsset:asset delegate:delegate];
    if ( self ) {
        mAsset = asset;
        mRequest = request;
        mDataType = dataType;
        mHTTPContent = content;
        mReadRange = range;
        mNetworkTaskPriority = priority;
        [mHTTPContent readwriteRetain]; // retain to prevent deletion
    }
    return self;
}

- (void)dealloc {
    [mHTTPContent readwriteRelease]; // release
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@: <%p> { request: %@ };\n", NSStringFromClass(self.class), self, mRequest.mcs_description];
}

- (void)prepareContent {
    MCSContentReaderDebugLog(@"%@: <%p>.prepareContent { request: %@ };\n", NSStringFromClass(self.class), self, mRequest);
    
    if ( mHTTPContent != nil ) {
        // broken point download
        if ( mReadRange.length > mHTTPContent.length ) {
            NSUInteger start = mReadRange.location + mHTTPContent.length;
            NSUInteger length = NSMaxRange(mReadRange) - start;
            NSRange newRange = NSMakeRange(start, length);
            NSMutableURLRequest *newRequest = [[mRequest mcs_requestWithRange:newRange] mcs_requestWithHTTPAdditionalHeaders:[mAsset.configuration HTTPAdditionalHeadersForDataRequestsOfType:mDataType]];
            mTask = [MCSDownload.shared downloadWithRequest:newRequest priority:mNetworkTaskPriority delegate:self];
        }
        [mHTTPContent readwriteRetain]; // retain for read
        [self contentDidReady:mHTTPContent range:mReadRange];
    }
    // download ts all content
    else {
        mTask = [MCSDownload.shared downloadWithRequest:[mRequest mcs_requestWithHTTPAdditionalHeaders:[mAsset.configuration HTTPAdditionalHeadersForDataRequestsOfType:mDataType]] priority:mNetworkTaskPriority delegate:self];
    }
}

#pragma mark - MCSDownloadTaskDelegate

- (void)downloadTask:(id<MCSDownloadTask>)task willPerformHTTPRedirectionWithNewRequest:(NSURLRequest *)request { }

- (void)downloadTask:(id<MCSDownloadTask>)task didReceiveResponse:(id<MCSDownloadResponse>)response {
    if ( mHTTPContent == nil ) {
        mHTTPContent = [mAsset createContentReadwriteWithDataType:mDataType response:response]; // retain for write
        
        if ( mHTTPContent == nil ) {
            [self abortWithError:[NSError mcs_errorWithCode:MCSInvalidResponseError userInfo:@{
                MCSErrorUserInfoObjectKey : response,
                MCSErrorUserInfoReasonKey : @"创建content失败!"
            }]];
            return;
        }
        
        [mHTTPContent readwriteRetain]; // retain for read
        [self contentDidReady:mHTTPContent range:response.range];
    }
}

- (void)downloadTask:(id<MCSDownloadTask>)task didReceiveData:(NSData *)data {
    NSError *error = nil;
    if ( ![mHTTPContent writeData:data error:&error] ) { // write data
        [self abortWithError:error];
    }
}

- (void)downloadTask:(id<MCSDownloadTask>)task didCompleteWithError:(NSError *)error {
    mTask = nil;
    if ( error != nil ) {
        [self abortWithError:error];
    }
}

- (void)didAbortWithError:(nullable NSError *)error {
    [mTask cancel];
}
@end
