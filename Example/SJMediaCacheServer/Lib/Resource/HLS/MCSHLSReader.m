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
#import "MCSHLSIndexFileDataReader.h"
#import "MCSResourceFileManager.h"
#import "MCSLogger.h"

@interface MCSHLSReader ()<NSLocking, MCSHLSIndexFileDataReaderDelegate> {
    NSRecursiveLock *_lock;
}
@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic, weak, nullable) MCSHLSResource *resource;
@property (nonatomic, strong, nullable) NSURLRequest *request;

@property (nonatomic, strong, nullable) id<MCSHLSDataReader> reader;
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
            _reader = [MCSHLSIndexFileDataReader.alloc initWithURL:_request.URL parser:_resource.parser];
            _reader.delegate = self;
            [_reader prepare];
        }
        else {
#ifdef DEBUG
            NSLog(@"%d - -[%@ %s]", (int)__LINE__, NSStringFromClass([self class]), sel_getName(_cmd));
#endif
        }
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    [self lock];
    @try {
        if ( _isClosed || _isReadingEndOfData )
            return nil;
        
        return [_reader readDataOfLength:length];
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

@synthesize isReadingEndOfData = _isReadingEndOfData;
- (BOOL)isReadingEndOfData {
    [self lock];
    @try {
        return _isReadingEndOfData;
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
- (NSString *)reader:(MCSHLSIndexFileDataReader *)reader AESKeyFilenameForURI:(NSString *)URI {
    return [MCSResourceFileManager hls_AESKeyFilenameForURI:URI];
}
// aes key
- (NSString *)reader:(MCSHLSIndexFileDataReader *)reader AESKeyWritePathForFilename:(NSString *)AESKeyFilename {
    return [MCSResourceFileManager getFilePathWithName:AESKeyFilename inResource:_resource.name];
}
// ts urls
- (NSString *)tsFragmentsWritePathForReader:(MCSHLSIndexFileDataReader *)reader {
    return [MCSResourceFileManager getFilePathWithName:[MCSResourceFileManager hls_tsFragmentsFilename] inResource:_resource.name];
}

// index.m3u8
- (NSString *)indexFileWritePathForReader:(MCSHLSIndexFileDataReader *)reader {
    return [MCSResourceFileManager hls_indexFilePathInResource:_resource.name];
}
// index.m3u8 contents
- (NSString *)reader:(MCSHLSIndexFileDataReader *)reader tsFilenameForUrl:(NSString *)url {
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
