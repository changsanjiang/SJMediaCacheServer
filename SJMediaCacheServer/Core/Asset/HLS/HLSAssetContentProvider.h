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

- (NSString *)getPlaylistFilePath;

- (NSString *)getAESKeyFilePath:(NSString *)filename;

- (nullable NSArray<NSString *> *)loadSegmentFilenames;
- (NSString *)getSegmentIdentifierByFilename:(NSString *)filename byteRange:(NSRange *)byteRangePtr;
- (id<HLSAssetSegment>)getSegmentByFilename:(NSString *)filename mimeType:(nullable NSString *)mimeType;

- (nullable id<HLSAssetSegment>)createSegmentWithIdentifier:(NSString *)identifier mimeType:(nullable NSString *)mimeType totalLength:(NSUInteger)totalLength;
- (nullable id<HLSAssetSegment>)createSegmentWithIdentifier:(NSString *)identifier mimeType:(nullable NSString *)mimeType totalLength:(NSUInteger)totalLength byteRange:(NSRange)byteRange;  // #EXT-X-BYTERANGE

- (void)removeSegment:(id<HLSAssetSegment>)content;
@end
NS_ASSUME_NONNULL_END
