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
- (nullable NSString *)writeContentsToPlaylist:(NSString *)contents error:(out NSError **)errorPtr;

- (nullable NSString *)loadAESKeyFilePathForIdentifier:(NSString *)identifier;
- (nullable NSString *)writeDataToAESKey:(NSData *)data forIdentifier:(NSString *)identifier error:(out NSError **)errorPtr;

- (nullable NSArray<NSString *> *)loadInitializationFilenames;
- (NSString *)getInitializationIdentifierByFilename:(NSString *)filename totalLength:(UInt64 *)totalLengthPtr byteRange:(NSRange *)byteRangePtr; // 获取标识和范围
- (id<MCSAssetContent>)getInitializationByFilename:(NSString *)filename mimeType:(nullable NSString *)mimeType;
- (nullable id<MCSAssetContent>)writeDataToInitialization:(NSData *)data forIdentifier:(NSString *)identifier mimeType:(nullable NSString *)mimeType error:(out NSError **)errorPtr;
- (nullable id<MCSAssetContent>)writeDataToInitialization:(NSData *)data forIdentifier:(NSString *)identifier mimeType:(nullable NSString *)mimeType totalLength:(NSUInteger)totalLength byteRange:(NSRange)byteRange error:(out NSError **)errorPtr; // 如果无 byteRange 可以传递 { NSNotFound, NSNotFound }

- (nullable NSString *)loadSubtitlesFilePathForIdentifier:(NSString *)identifier;
- (nullable NSString *)writeDataToSubtitles:(NSData *)data forIdentifier:(NSString *)identifier error:(out NSError **)errorPtr;

- (nullable NSArray<NSString *> *)loadSegmentFilenames;
- (NSString *)getSegmentIdentifierByFilename:(NSString *)filename byteRange:(NSRange *)byteRangePtr;
- (id<HLSAssetSegment>)getSegmentByFilename:(NSString *)filename mimeType:(nullable NSString *)mimeType; // 获取标识和范围

- (nullable id<HLSAssetSegment>)createSegmentWithIdentifier:(NSString *)identifier mimeType:(nullable NSString *)mimeType totalLength:(NSUInteger)totalLength error:(NSError **)errorPtr;
- (nullable id<HLSAssetSegment>)createSegmentWithIdentifier:(NSString *)identifier mimeType:(nullable NSString *)mimeType totalLength:(NSUInteger)totalLength byteRange:(NSRange)byteRange error:(NSError **)errorPtr;  // #EXT-X-BYTERANGE

- (void)removeSegment:(id<HLSAssetSegment>)content;
- (void)clear;
@end
NS_ASSUME_NONNULL_END
