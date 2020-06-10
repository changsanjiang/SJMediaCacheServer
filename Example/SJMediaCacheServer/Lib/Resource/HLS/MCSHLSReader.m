//
//  MCSHLSReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSReader.h"
#import "MCSHLSResource.h"
#import "MCSHLSResource+MCSPrivate.h"
#import "MCSHLSIndexDataReader.h"
#import "MCSHLSTSDataReader.h"
#import "MCSResourceFileManager.h"
#import "MCSLogger.h"

@interface MCSHLSReader ()<NSLocking, MCSHLSIndexDataReaderDelegate> {
    NSRecursiveLock *_lock;
}
@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic, weak, nullable) MCSHLSResource *resource;
@property (nonatomic, strong, nullable) NSURLRequest *request;

@property (nonatomic, strong, nullable) id<MCSHLSDataReader> reader;
@property (nonatomic) NSUInteger offset;
@end

@implementation MCSHLSReader
- (instancetype)initWithResource:(__weak MCSHLSResource *)resource request:(NSURLRequest *)request {
    self = [super init];
    if ( self ) {
        _resource = resource;
        _request = request;
        _lock = NSRecursiveLock.alloc.init;
    }
    return self;
}

- (void)prepare {
    [self lock];
    @try {
        if ( _isClosed || _isCalledPrepare )
            return;
        
        _isCalledPrepare = YES;
        
        if ( [_request.URL.absoluteString containsString:@".m3u8"] ) {
            _reader = [MCSHLSIndexDataReader.alloc initWithURL:_request.URL parser:_resource.parser];
            _reader.delegate = self;
            [_reader prepare];
        }
        else {
            NSAssert(_resource.parser != nil, @"`parser`不能为nil!");
            _reader = [MCSHLSTSDataReader.alloc initWithRequest:_request parser:_resource.parser];
        }
        
        _reader.delegate = self;
        [_reader prepare];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    [self lock];
    @try {
        if ( _isClosed || _reader.isDone )
            return nil;
        
        NSData *data = [_reader readDataOfLength:length];
        _offset += data.length;
        return data;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        if ( self.reader.isDone ) [self close];
        [self unlock];
    }
}

- (void)close {
    [self lock];
    @try {
        if ( _isClosed )
            return;
        
        _isClosed = YES;
        [_reader close];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
    
//    MCSLog(@"%@: <%p>.close { range: %@ };\n", NSStringFromClass(self.class), self, NSStringFromRange(_request.mcs_range));
}

- (BOOL)isReadingEndOfData {
    [self lock];
    @try {
        return _reader.isDone;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

@synthesize isClosed = _isClosed;
- (BOOL)isClosed {
    [self lock];
    @try {
        return _isClosed;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (id<MCSResourceResponse>)response {
    [self lock];
    @try {
        return _reader.response;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

#pragma mark -

- (void)lock {
    [_lock lock];
}

- (void)unlock {
    [_lock unlock];
}

#pragma mark -
// aes key
- (NSString *)reader:(MCSHLSIndexDataReader *)reader AESKeyFilenameForURI:(NSString *)URI {
    return [MCSResourceFileManager hls_AESKeyFilenameForURI:URI];
}
// aes key
- (NSString *)reader:(MCSHLSIndexDataReader *)reader AESKeyWritePathForFilename:(NSString *)AESKeyFilename {
    return [MCSResourceFileManager getFilePathWithName:AESKeyFilename inResource:_resource.name];
}
// ts urls
- (NSString *)tsFragmentsWritePathForReader:(MCSHLSIndexDataReader *)reader {
    return [MCSResourceFileManager getFilePathWithName:[MCSResourceFileManager hls_tsFragmentsFilename] inResource:_resource.name];
}

// index.m3u8
- (NSString *)indexFileWritePathForReader:(MCSHLSIndexDataReader *)reader {
    return [MCSResourceFileManager hls_indexFilePathInResource:_resource.name];
}
// index.m3u8 contents
- (NSString *)reader:(MCSHLSIndexDataReader *)reader tsFilenameForUrl:(NSString *)url {
    return [MCSResourceFileManager hls_tsFilenameForUrl:url];
}

#pragma mark -

- (void)readerPrepareDidFinish:(id<MCSResourceDataReader>)reader {
    [self lock];
    _isPrepared = YES;
    [self unlock];
    [self.delegate readerPrepareDidFinish:self];
}
- (void)readerHasAvailableData:(id<MCSResourceDataReader>)reader {
    [self.delegate readerHasAvailableData:self];
}
- (void)reader:(id<MCSResourceDataReader>)reader anErrorOccurred:(NSError *)error {
    [self.delegate reader:self anErrorOccurred:error];
}
@end
