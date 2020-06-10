//
//  MCSHLSIndexDataReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/10.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSIndexDataReader.h"
#import "MCSLogger.h"
#import "MCSResourceFileDataReader.h"
#import "MCSResourceResponse.h"

@interface MCSHLSIndexDataReader ()<MCSHLSParserDelegate, MCSResourceDataReaderDelegate>
@property (nonatomic, strong) NSURL *URL;

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isClosed;
@property (nonatomic) BOOL isDone;

@property (nonatomic, strong, nullable) MCSResourceFileDataReader *reader;
@end

@implementation MCSHLSIndexDataReader
@synthesize delegate = _delegate;
- (instancetype)initWithURL:(NSURL *)URL parser:(nullable MCSHLSParser *)parser {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _parser = parser;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { URL: %@\n };", NSStringFromClass(self.class), self, _URL];
}

- (void)prepare {
    if ( _isClosed || _isCalledPrepare )
        return;
    
    MCSLog(@"%@: <%p>.prepare { URL: %@ };\n", NSStringFromClass(self.class), self, _URL);

    _isCalledPrepare = YES;
    
    if ( _parser == nil ) {
        _parser = [MCSHLSParser.alloc initWithURL:_URL delegate:self];
        [_parser prepare];
    }
    else {
        [self _parseDidFinish];
    }
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    return [_reader readDataOfLength:length];
}

- (BOOL)isDone {
    return _reader.isDone;
}

- (void)close {
    if ( _isClosed )
        return;
    _isClosed = YES;
    [_reader close];
    
    MCSLog(@"%@: <%p>.close { URL: %@ };\n", NSStringFromClass(self.class), self, _URL);
}

#pragma mark -

- (void)_parseDidFinish {
    NSString *indexFilePath = _parser.indexFilePath;
    NSUInteger fileSize = [NSFileManager.defaultManager attributesOfItemAtPath:indexFilePath error:NULL].fileSize;
    NSRange range = NSMakeRange(0, fileSize);
    _reader = [MCSResourceFileDataReader.alloc initWithRange:range path:indexFilePath readRange:range];
    _reader.delegate = self;
    [_reader prepare];
}

#pragma mark -

// aes key
- (NSString *)parser:(MCSHLSParser *)parser AESKeyFilenameForURI:(NSString *)URI {
    return [(id<MCSHLSIndexDataReaderDelegate>)_delegate reader:self AESKeyFilenameForURI:URI];
}
// aes key
- (NSString *)parser:(MCSHLSParser *)parser AESKeyWritePathForFilename:(NSString *)AESKeyFilename {
    return [(id<MCSHLSIndexDataReaderDelegate>)_delegate reader:self AESKeyWritePathForFilename:AESKeyFilename];
}
// ts urls
- (NSString *)tsFragmentsWritePathForParser:(MCSHLSParser *)parser {
    return [(id<MCSHLSIndexDataReaderDelegate>)_delegate tsFragmentsWritePathForReader:self];
}

// index.m3u8
- (NSString *)indexFileWritePathForParser:(MCSHLSParser *)parser {
    return [(id<MCSHLSIndexDataReaderDelegate>)_delegate indexFileWritePathForReader:self];
}
// index.m3u8 contents
- (NSString *)parser:(MCSHLSParser *)parser tsFilenameForUrl:(NSString *)url {
    return [(id<MCSHLSIndexDataReaderDelegate>)_delegate reader:self tsFilenameForUrl:url];
}

- (void)parserParseDidFinish:(MCSHLSParser *)parser {
    [self _parseDidFinish];
}

- (void)parser:(MCSHLSParser *)parser anErrorOccurred:(NSError *)error {
    [self.delegate reader:self anErrorOccurred:error];
}

#pragma mark -

- (void)readerPrepareDidFinish:(id<MCSResourceDataReader>)reader {
    NSString *indexFilePath = _parser.indexFilePath;
    NSUInteger length = [NSFileManager.defaultManager attributesOfItemAtPath:indexFilePath error:NULL].fileSize;
    _response = [MCSResourceResponse.alloc initWithServer:@"localhost" contentType:@"application/x-mpegurl" totalLength:length];
    [self.delegate readerPrepareDidFinish:self];
}

- (void)readerHasAvailableData:(id<MCSResourceDataReader>)reader {
    [self.delegate readerHasAvailableData:self];
}

- (void)reader:(id<MCSResourceDataReader>)reader anErrorOccurred:(NSError *)error {
    [self.delegate reader:self anErrorOccurred:error];
}

@end
