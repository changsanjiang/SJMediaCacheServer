//
//  HLSAssetContentProvider.h
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/11/25.
//
 
#import "HLSAssetDefines.h"
@class HLSAssetParser;

NS_ASSUME_NONNULL_BEGIN

@interface HLSAssetContentProvider : NSObject
- (instancetype)initWithDirectory:(NSString *)directory;

- (nullable NSString *)loadPlaylistFilePath;
- (nullable NSString *)writeContentsToPlaylist:(NSString *)contents error:(out NSError **)error;

- (nullable NSString *)loadAESKeyFilePathForIdentifier:(NSString *)identifier;
- (nullable NSString *)writeDataToAESKey:(NSData *)data forIdentifier:(NSString *)identifier error:(out NSError **)error;

- (nullable NSString *)loadSubtitlesFilePathForIdentifier:(NSString *)identifier;
- (nullable NSString *)writeDataToSubtitles:(NSData *)data forIdentifier:(NSString *)identifier error:(out NSError **)error;

- (nullable NSArray<NSString *> *)loadInitializationFilenames;
- (NSString *)getInitializationIdentifierByFilename:(NSString *)filename byteRange:(NSRange *)byteRangePtr; // 获取标识和范围
- (nullable NSString *)writeDataToInitialization:(NSData *)data forIdentifier:(NSString *)identifier error:(out NSError **)error;
- (nullable NSString *)writeDataToInitialization:(NSData *)data forIdentifier:(NSString *)identifier byteRange:(NSRange)byteRange error:(out NSError **)error;

- (nullable NSArray<NSString *> *)loadSegmentFilenames;
- (NSString *)getSegmentIdentifierByFilename:(NSString *)filename byteRange:(NSRange *)byteRangePtr;
- (id<HLSAssetSegment>)getSegmentByFilename:(NSString *)filename mimeType:(nullable NSString *)mimeType; // 获取标识和范围

- (nullable id<HLSAssetSegment>)createSegmentWithIdentifier:(NSString *)identifier mimeType:(nullable NSString *)mimeType totalLength:(NSUInteger)totalLength error:(NSError **)error;
- (nullable id<HLSAssetSegment>)createSegmentWithIdentifier:(NSString *)identifier mimeType:(nullable NSString *)mimeType totalLength:(NSUInteger)totalLength byteRange:(NSRange)byteRange error:(NSError **)error;  // #EXT-X-BYTERANGE

- (void)removeSegment:(id<HLSAssetSegment>)content;
- (void)clear;
@end
NS_ASSUME_NONNULL_END
