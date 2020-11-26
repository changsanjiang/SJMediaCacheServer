//
//  HLSReader.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "HLSReader.h"
#import "HLSContentIndexReader.h"
#import "HLSContentAESKeyReader.h"
#import "HLSContentTSReader.h" 
#import "MCSLogger.h"
#import "HLSAsset.h"
#import "MCSAssetManager.h"
#import "MCSError.h"
#import "MCSQueue.h"
#import "MCSResponse.h"
#import "MCSConsts.h"

@interface HLSReader ()<MCSAssetDataReaderDelegate>
@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic, weak, nullable) HLSAsset *asset;
@property (nonatomic, strong, nullable) NSURLRequest *request;
@property (nonatomic, strong, nullable) id<MCSAssetDataReader> reader;
@end

@implementation HLSReader
@synthesize readDataDecoder = _readDataDecoder;
@synthesize isClosed = _isClosed;
@synthesize response = _response;

- (instancetype)initWithAsset:(__weak HLSAsset *)asset request:(NSURLRequest *)request {
    self = [super init];
    if ( self ) {
        _networkTaskPriority = 1.0;
        _asset = asset;
        _request = request;
        
        [_asset readwriteRetain];
        
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(willRemoveAssetWithNote:) name:MCSAssetWillRemoveAssetNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    if ( !_isClosed ) [self _close];
    [_asset readwriteRelease];
    MCSAssetReaderDebugLog(@"%@: <%p>.dealloc;\n", NSStringFromClass(self.class), self);
}

- (void)willRemoveAssetWithNote:(NSNotification *)note {
    id<MCSAsset> asset = note.object;
    if ( asset == _asset )  {
        dispatch_barrier_sync(dispatch_get_global_queue(0, 0), ^{
            if ( _isClosed )
                return;
            [self _onError:[NSError mcs_errorWithCode:MCSFileError userInfo:@{
                MCSErrorUserInfoObjectKey : _request,
                MCSErrorUserInfoReasonKey : @"资源将要被删除!"
            }]];
        });
    }
}

- (void)prepare {
    dispatch_barrier_sync(dispatch_get_global_queue(0, 0), ^{
        if ( _isClosed || _isCalledPrepare )
            return;
        
        MCSAssetReaderDebugLog(@"%@: <%p>.prepare { name: %@, request: %@ };\n", NSStringFromClass(self.class), self, _asset.name, _request);

        NSParameterAssert(_asset);
         
        _isCalledPrepare = YES;
        NSURL *URL = [MCSURLRecognizer.shared URLWithProxyURL:_request.URL];
        NSMutableURLRequest *request = [_request mcs_requestWithRedirectURL:URL];
        if      ( [_request.URL.absoluteString containsString:HLS_SUFFIX_INDEX] ) {
            _reader = [HLSContentIndexReader.alloc initWithAsset:_asset request:request networkTaskPriority:_networkTaskPriority delegate:self];
        }
        else {
            if ( _asset.parser == nil ) {
                [self _onError:[NSError mcs_errorWithCode:MCSUnknownError userInfo:@{
                    MCSErrorUserInfoObjectKey : _request,
                    MCSErrorUserInfoReasonKey : @"解析器为空, 索引文件可能未解析!"
                }]];
                return;
            }
            
            if ( [_request.URL.absoluteString containsString:HLS_SUFFIX_AES_KEY] ) {
                _reader = [HLSContentAESKeyReader.alloc initWithAsset:_asset request:request networkTaskPriority:_networkTaskPriority delegate:self];
            }
            else {
                _reader = [HLSContentTSReader.alloc initWithAsset:_asset request:request networkTaskPriority:_networkTaskPriority delegate:self];
            }
        }
        
        [_reader prepare];
    });
}

- (nullable id<MCSAssetDataReader>)reader {
    __block id<MCSAssetDataReader> reader = nil;
    dispatch_sync(dispatch_get_global_queue(0, 0), ^{
        reader = _reader;
    });
    return reader;
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    __block NSData *data = nil;
    dispatch_barrier_sync(dispatch_get_global_queue(0, 0), ^{
        NSUInteger offset = _reader.offset;
        data = [_reader readDataOfLength:length];
        
        if ( data != nil && _readDataDecoder != nil ) {
            data = _readDataDecoder(_request, offset, data);
        }
        
        if ( _reader.isDone ) {
            MCSAssetReaderDebugLog(@"%@: <%p>.done;\n", NSStringFromClass(self.class), self);
            [self _close];
        }
    });
    return data;
}

- (BOOL)seekToOffset:(NSUInteger)offset {
    __block BOOL result = NO;
    dispatch_barrier_sync(dispatch_get_global_queue(0, 0), ^{
        if ( _isClosed || !_reader.isPrepared )
            return;
        
        result = [_reader seekToOffset:offset];
        if ( _reader.isDone ) {
            MCSAssetReaderDebugLog(@"%@: <%p>.done;\n", NSStringFromClass(self.class), self);
            [self _close];
        }
    });
    return result;
}

- (void)close {
    dispatch_barrier_sync(dispatch_get_global_queue(0, 0), ^{
        [self _close];
    });
}

#pragma mark -

- (id<MCSResponse>)response {
    __block id<MCSResponse> response = nil;
    dispatch_sync(dispatch_get_global_queue(0, 0), ^{
        response = _response;
    });
    return response;
}
 
- (NSUInteger)availableLength {
    return self.reader.availableLength;
}

- (NSUInteger)offset {
    return self.reader.offset;
}

- (BOOL)isPrepared {
    return self.reader.isPrepared;
}

- (BOOL)isReadingEndOfData {
    return self.reader.isDone;
}

- (BOOL)isClosed {
    __block BOOL result = NO;
    dispatch_sync(dispatch_get_global_queue(0, 0), ^{
        result = _isClosed;
    });
    return result;
}
 
#pragma mark -

- (void)_close {
    if ( _isClosed )
        return;
    
    [_reader close];
     
    _isClosed = YES;
    
    MCSAssetReaderDebugLog(@"%@: <%p>.close;\n", NSStringFromClass(self.class), self);
}

#pragma mark -

- (void)readerPrepareDidFinish:(id<MCSAssetDataReader>)reader {
    dispatch_barrier_sync(dispatch_get_global_queue(0, 0), ^{
        _response = [MCSResponse.alloc initWithTotalLength:reader.range.length contentType:[reader isKindOfClass:HLSContentTSReader.class] ? _asset.TsContentType : nil];
    });
    [_delegate reader:self prepareDidFinish:self.response];
}

- (void)reader:(id<MCSAssetDataReader>)reader hasAvailableDataWithLength:(NSUInteger)length {
    [_delegate reader:self hasAvailableDataWithLength:length];
}

- (void)reader:(id<MCSAssetDataReader>)reader anErrorOccurred:(NSError *)error {
    dispatch_barrier_sync(dispatch_get_global_queue(0, 0), ^{
        [self _onError:error];
    });
}

- (void)_onError:(NSError *)error {
    if ( _isClosed )
        return;
    [self _close];
    MCSAssetReaderErrorLog(@"%@: <%p>.error { error: %@ };\n", NSStringFromClass(self.class), self, error);
    
    dispatch_async(MCSDelegateQueue(), ^{
        [self->_delegate reader:self anErrorOccurred:error];
    });
}
@end
