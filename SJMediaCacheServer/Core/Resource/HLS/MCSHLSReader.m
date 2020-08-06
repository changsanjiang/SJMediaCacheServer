//
//  MCSHLSReader.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSReader.h"
#import "MCSHLSResource.h"
#import "MCSHLSIndexDataReader.h"
#import "MCSHLSAESKeyDataReader.h"
#import "MCSHLSTSDataReader.h"
#import "MCSFileManager.h"
#import "MCSLogger.h"
#import "MCSHLSResource.h"
#import "MCSResourceManager.h"
#import "MCSError.h"
#import "MCSQueue.h"

#import "MCSResourceFileDataReader2.h"
#import "MCSResourceNetworkDataReader.h"

@interface MCSHLSReader ()<MCSResourceDataReaderDelegate> 
@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isPrepared;
@property (nonatomic, weak, nullable) MCSHLSResource *resource;
@property (nonatomic, strong, nullable) NSURLRequest *request;
@property (nonatomic, strong, nullable) id<MCSResourceDataReader> reader;
@property (nonatomic, strong, nullable) id<MCSResourceResponse> response;
@end

@implementation MCSHLSReader
@synthesize readDataDecoder = _readDataDecoder;
@synthesize isClosed = _isClosed;

- (instancetype)initWithResource:(__weak MCSHLSResource *)resource request:(NSURLRequest *)request {
    self = [super init];
    if ( self ) {
        _networkTaskPriority = 1.0;
        _resource = resource;
        _request = request;
        [_resource readWrite_retain];
        [MCSResourceManager.shared reader:self willReadResource:resource];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didRemoveResource:) name:MCSResourceManagerDidRemoveResourceNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(userCancelledReading:) name:MCSResourceManagerUserCancelledReadingNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [_resource readWrite_release];
    [MCSResourceManager.shared reader:self didEndReadResource:_resource];
    if ( !_isClosed ) [self _close];
    MCSResourceReaderLog(@"%@: <%p>.dealloc;\n", NSStringFromClass(self.class), self);
}

- (void)didRemoveResource:(NSNotification *)note {
    MCSResource *resource = note.userInfo[MCSResourceManagerUserInfoResourceKey];
    if ( resource == _resource )  {
        dispatch_barrier_sync(MCSReaderQueue(), ^{
            if ( _isClosed )
                return;
            [self _onError:[NSError mcs_removedResource:_request.URL]];
        });
    }
}

- (void)userCancelledReading:(NSNotification *)note {
    MCSResource *resource = note.userInfo[MCSResourceManagerUserInfoResourceKey];
    if ( resource == _resource && !self.isClosed )  {
        dispatch_barrier_sync(MCSReaderQueue(), ^{
           if ( _isClosed )
               return;
            [self _onError:[NSError mcs_userCancelledError:_request.URL]];
        });
    }
}

- (void)prepare {
    dispatch_barrier_sync(MCSReaderQueue(), ^{
        if ( _isClosed || _isCalledPrepare )
            return;
        
        MCSResourceReaderLog(@"%@: <%p>.prepare { name: %@, URL: %@ };\n", NSStringFromClass(self.class), self, _resource.name, _request.URL);

        NSParameterAssert(_resource);
        
        _isCalledPrepare = YES;
        NSURL *proxyURL = _request.URL;
        MCSDataType dataType = [MCSURLRecognizer.shared dataTypeForProxyURL:proxyURL];
        switch ( dataType ) {
            case MCSDataTypeHLSPlaylist: {
                _reader = [MCSHLSIndexDataReader.alloc initWithResource:_resource proxyRequest:_request networkTaskPriority:_networkTaskPriority delegate:self];
            }
                break;
            case MCSDataTypeHLSAESKey:
            case MCSDataTypeHLSTs: {
                if ( _resource.parser == nil ) {
                    [self _onError:[NSError mcs_HLSFileParseError:_request.URL]];
                    return;
                }
                
                MCSHLSPartialContent *content = [_resource contentForProxyURL:_request.URL];
                if ( content != nil ) {
                    _reader = [MCSResourceFileDataReader2.alloc initWithResource:_resource inRange:NSMakeRange(0, content.totalLength) partialContent:content startOffsetInFile:0 delegate:self];
                }
                else {
                    _reader = [MCSResourceNetworkDataReader.alloc initWithResource:_resource proxyRequest:_request networkTaskPriority:_networkTaskPriority delegate:self];
                }
            }
                break;
            default:
                assert("Invalid data type!");
                break;
        }
        [_reader prepare];
    });
}

- (nullable id<MCSResourceDataReader>)reader {
    __block id<MCSResourceDataReader> reader = nil;
    dispatch_sync(MCSReaderQueue(), ^{
        reader = _reader;
    });
    return reader;
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    __block NSData *data = nil;
    dispatch_barrier_sync(MCSReaderQueue(), ^{
        if ( _reader.isDone )
            return;
        
        NSUInteger offset = _reader.offset;
        data = [_reader readDataOfLength:length];
        
        if ( data != nil && _readDataDecoder != nil ) {
            data = _readDataDecoder(_request, offset, data);
        }
        
#ifdef DEBUG
        if ( _reader.isDone ) {
            MCSResourceReaderLog(@"%@: <%p>.done { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);
        }
#endif
    });
    return data;
}

- (BOOL)seekToOffset:(NSUInteger)offset {
    return [self.reader seekToOffset:offset];
}

- (void)close {
    dispatch_barrier_sync(MCSReaderQueue(), ^{
        [self _close];
    });
}

#pragma mark -

- (NSUInteger)availableLength {
    return self.reader.availableLength;
}

- (NSUInteger)offset {
    return self.reader.offset;
}

- (BOOL)isPrepared {
    __block BOOL isPrepared = NO;
    dispatch_sync(MCSReaderQueue(), ^{
        isPrepared = _isPrepared;
    });
    return isPrepared;
}

- (BOOL)isReadingEndOfData {
    return self.reader.isDone;
}

- (BOOL)isClosed {
    __block BOOL result = NO;
    dispatch_sync(MCSReaderQueue(), ^{
        result = _isClosed;
    });
    return result;
}

- (id<MCSResourceResponse>)response {
    __block id<MCSResourceResponse> response = nil;
    dispatch_sync(MCSReaderQueue(), ^{
        response = _response;
    });
    return response;
}

#pragma mark -

- (void)_close {
    if ( _isClosed )
        return;
    
    [_reader close];
     
    _isClosed = YES;
    
    MCSResourceReaderLog(@"%@: <%p>.close { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);
}

#pragma mark -

- (void)readerPrepareDidFinish:(id<MCSResourceDataReader>)reader {
    dispatch_barrier_sync(MCSReaderQueue(), ^{
        if ( [reader isKindOfClass:MCSHLSIndexDataReader.class] ) {
            MCSHLSParser *parser = [(MCSHLSIndexDataReader *)reader parser];
            if ( parser != nil && _resource.parser != parser )
                _resource.parser = parser;
        }

        _response = [MCSResourceResponse.alloc initWithServer:@"localhost" contentType:@"application/octet-stream" totalLength:reader.range.length];
        _isPrepared = YES;
    });
    [_delegate readerPrepareDidFinish:self];
}

- (void)reader:(id<MCSResourceDataReader>)reader hasAvailableDataWithLength:(NSUInteger)length {
    [_delegate reader:self hasAvailableDataWithLength:length];
}

- (void)reader:(id<MCSResourceDataReader>)reader anErrorOccurred:(NSError *)error {
    dispatch_barrier_sync(MCSReaderQueue(), ^{
        [self _onError:error];
    });
}

- (void)_onError:(NSError *)error {
    if ( _isClosed )
        return;
    [self _close];
    MCSResourceReaderLog(@"%@: <%p>.error { error: %@ };\n", NSStringFromClass(self.class), self, error);
    
    dispatch_async(MCSDelegateQueue(), ^{
        [self->_delegate reader:self anErrorOccurred:error];
    });
}
@end
