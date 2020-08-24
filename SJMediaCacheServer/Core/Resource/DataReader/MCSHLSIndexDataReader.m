//
//  MCSHLSIndexDataReader.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/10.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSIndexDataReader.h"
#import "MCSResourceDataReaderSubclass.h"
#import "MCSLogger.h"
#import "MCSResourceResponse.h"
#import "MCSHLSResource.h"
#import "MCSFileManager.h"
#import "MCSQueue.h"
#import "MCSURLRecognizer.h"
#import "MCSContentFileRead.h"

@interface MCSHLSIndexDataReader ()<MCSHLSParserDelegate>
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic) float networkTaskPriority;
@end

@implementation MCSHLSIndexDataReader
- (instancetype)initWithResource:(MCSHLSResource *)resource proxyRequest:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority delegate:(id<MCSResourceDataReaderDelegate>)delegate {
    self = [super initWithResource:resource delegate:delegate];
    if ( self ) {
        _networkTaskPriority = networkTaskPriority;
        _request = request;
        _parser = resource.parser;
    }
    return self;
}

- (void)dealloc {
    if ( !_isClosed ) [self _close];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { URL: %@\n };", NSStringFromClass(self.class), self, _request.URL];
}

- (void)_prepare {
    MCSDataReaderLog(@"%@: <%p>.prepare { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);
    
    NSParameterAssert(_resource);
    
    _isCalledPrepare = YES;
    
    // parse the m3u8 file
    if ( _parser == nil ) {
        NSURL *proxyURL = _request.URL;
        NSURL *URL = [MCSURLRecognizer.shared URLWithProxyURL:proxyURL];
        NSMutableURLRequest *request = [_request mcs_requestWithRedirectURL:URL];
        [request mcs_requestWithHTTPAdditionalHeaders:[_resource.configuration HTTPAdditionalHeadersForDataRequestsOfType:MCSDataTypeHLSPlaylist]];
        _parser = [MCSHLSParser.alloc initWithResource:_resource.name request:request networkTaskPriority:_networkTaskPriority delegate:self];
        [_parser prepare];
        return;
    }
    
    [self _parseDidFinish];
}
   
#pragma mark - MCSHLSParserDelegate

- (void)parserParseDidFinish:(MCSHLSParser *)parser {
    dispatch_barrier_sync(MCSDataReaderQueue(), ^{
        [self _parseDidFinish];
    });
}

- (void)parser:(MCSHLSParser *)parser anErrorOccurred:(NSError *)error {
    dispatch_barrier_sync(MCSDataReaderQueue(), ^{
        [self _onError:error];
    });
}

#pragma mark -

- (void)_onError:(NSError *)error {
    [self _close];
    
    dispatch_async(MCSDelegateQueue(), ^{
        [self->_delegate reader:self anErrorOccurred:error];
    });
}

- (void)_close {
    @try {
        _reader = nil;
        _reader = nil;
        _isClosed = YES;

        MCSDataReaderLog(@"%@: <%p>.close { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);
    } @catch (NSException *exception) {
        
    }
}

- (void)_parseDidFinish {
    if ( _reader != nil )
        return;
    
    MCSHLSResource *resource = _resource;
    [resource parseDidFinish:_parser];
    
    NSString *filePath = _parser.indexFilePath;
    NSUInteger fileSize = [MCSFileManager fileSizeAtPath:filePath];
    _range = NSMakeRange(0, fileSize);
    _reader = [MCSContentFileRead readerWithPath:filePath];
    
    if ( _reader == nil ) {
        [self _onError:[NSError mcs_errorWithCode:MCSFileNotExistError userInfo:@{
            MCSErrorUserInfoResourceKey : _resource,
            MCSErrorUserInfoRequestKey : _request,
            MCSErrorUserInfoRequestAllHeaderFieldsKey : _request.allHTTPHeaderFields,
            NSLocalizedDescriptionKey : @"初始化 reader 失败, 文件可能不存在!"
        }]];
        return;
    }
    
    _availableLength = fileSize;
    _isPrepared = YES;
    dispatch_async(MCSDelegateQueue(), ^{
        [self->_delegate readerPrepareDidFinish:self];
        [self->_delegate reader:self hasAvailableDataWithLength:self->_availableLength];
    });
}
@end
