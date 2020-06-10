//
//  MCSHLSIndexDataReader.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/10.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSDataReader.h"
#import "MCSHLSParser.h"
@protocol MCSResourceResponse;

NS_ASSUME_NONNULL_BEGIN

@interface MCSHLSIndexDataReader : NSObject<MCSHLSDataReader>
- (instancetype)initWithURL:(NSURL *)URL parser:(nullable MCSHLSParser *)parser;

- (void)prepare;
@property (nonatomic, strong, readonly, nullable) MCSHLSParser *parser;
@property (nonatomic, readonly) BOOL isDone;
@property (nonatomic, strong, readonly, nullable) id<MCSResourceResponse> response;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (void)close;

@end

@protocol MCSHLSIndexDataReaderDelegate <MCSResourceDataReaderDelegate>
// aes key
- (NSString *)reader:(MCSHLSIndexDataReader *)reader AESKeyFilenameForURI:(NSString *)URI;
// aes key
- (NSString *)reader:(MCSHLSIndexDataReader *)reader AESKeyWritePathForFilename:(NSString *)AESKeyFilename;
// ts urls
- (NSString *)tsFragmentsWritePathForReader:(MCSHLSIndexDataReader *)reader;

// index.m3u8
- (NSString *)indexFileWritePathForReader:(MCSHLSIndexDataReader *)reader;
// index.m3u8 contents
- (NSString *)reader:(MCSHLSIndexDataReader *)reader tsNameForUrl:(NSString *)url;
@end
NS_ASSUME_NONNULL_END
