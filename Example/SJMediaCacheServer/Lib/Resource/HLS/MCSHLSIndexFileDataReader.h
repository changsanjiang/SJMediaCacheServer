//
//  MCSHLSIndexFileDataReader.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/10.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSDataReader.h"
#import "MCSHLSParser.h"
@protocol MCSResourceResponse;

NS_ASSUME_NONNULL_BEGIN

@interface MCSHLSIndexFileDataReader : NSObject<MCSHLSDataReader>
- (instancetype)initWithURL:(NSURL *)URL parser:(nullable MCSHLSParser *)parser;

- (void)prepare;
@property (nonatomic, strong, readonly, nullable) MCSHLSParser *parser;
@property (nonatomic, readonly) BOOL isDone;
@property (nonatomic, strong, readonly, nullable) id<MCSResourceResponse> response;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (void)close;

@end

@protocol MCSHLSIndexFileDataReaderDelegate <MCSResourceDataReaderDelegate>
// aes key
- (NSString *)reader:(MCSHLSIndexFileDataReader *)reader AESKeyFilenameForURI:(NSString *)URI;
// aes key
- (NSString *)reader:(MCSHLSIndexFileDataReader *)reader AESKeyWritePathForFilename:(NSString *)AESKeyFilename;
// ts urls
- (NSString *)tsFragmentsWritePathForReader:(MCSHLSIndexFileDataReader *)reader;

// index.m3u8
- (NSString *)indexFileWritePathForReader:(MCSHLSIndexFileDataReader *)reader;
// index.m3u8 contents
- (NSString *)reader:(MCSHLSIndexFileDataReader *)reader tsFilenameForUrl:(NSString *)url;
@end
NS_ASSUME_NONNULL_END
