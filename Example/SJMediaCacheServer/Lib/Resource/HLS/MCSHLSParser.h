//
//  MCSHLSParser.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol MCSHLSParserDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface MCSHLSParser : NSObject
- (instancetype)initWithURL:(NSURL *)URL delegate:(id<MCSHLSParserDelegate>)delegate;

- (void)prepare;

- (void)close;

@property (nonatomic, readonly) BOOL isClosed;
@property (nonatomic, readonly) BOOL isDone;

@property (nonatomic, copy, readonly) NSString *indexFilePath;
- (NSURL *)tsURLWithTsName:(NSString *)tsName;
@end


@protocol MCSHLSParserDelegate <NSObject>
// aes key
- (NSString *)parser:(MCSHLSParser *)parser AESKeyFilenameForURI:(NSString *)URI;
// aes key
- (NSString *)parser:(MCSHLSParser *)parser AESKeyWritePathForFilename:(NSString *)AESKeyFilename;
// ts urls
- (NSString *)tsFragmentsWritePathForParser:(MCSHLSParser *)parser;

// index.m3u8
- (NSString *)indexFileWritePathForParser:(MCSHLSParser *)parser;
// index.m3u8 contents
- (NSString *)parser:(MCSHLSParser *)parser tsNameForUrl:(NSString *)url;

- (void)parserParseDidFinish:(MCSHLSParser *)parser;
- (void)parser:(MCSHLSParser *)parser anErrorOccurred:(NSError *)error;
@end

NS_ASSUME_NONNULL_END
