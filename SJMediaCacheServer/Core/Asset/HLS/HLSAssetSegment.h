//
//  HLSAssetSegment.h
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/11/25.
//

#import "MCSAssetContent.h"
#import "HLSAssetDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface HLSAssetSegment : MCSAssetContent<HLSAssetSegment>
- (instancetype)initWithMimeType:(nullable NSString *)mimeType filePath:(NSString *)filePath totalLength:(UInt64)totalLength;
- (instancetype)initWithMimeType:(nullable NSString *)mimeType filePath:(NSString *)filePath totalLength:(UInt64)totalLength length:(UInt64)length;
- (instancetype)initWithMimeType:(nullable NSString *)mimeType filePath:(NSString *)filePath totalLength:(UInt64)totalLength byteRange:(NSRange)byteRange; // byte range
- (instancetype)initWithMimeType:(nullable NSString *)mimeType filePath:(NSString *)filePath totalLength:(UInt64)totalLength length:(UInt64)length byteRange:(NSRange)byteRange; // byte range

@property (nonatomic, readonly) UInt64 totalLength; // segment file totalLength or #EXT-X-BYTERANGE:1544984@1007868
@property (nonatomic, readonly) NSRange byteRange; // segment file {0, totalLength} or #EXT-X-BYTERANGE:1544984@1007868

- (instancetype)initWithMimeType:(nullable NSString *)mimeType filePath:(NSString *)filePath startPositionInAsset:(UInt64)position length:(UInt64)length NS_UNAVAILABLE;
- (instancetype)initWithFilePath:(NSString *)filePath startPositionInAsset:(UInt64)position length:(UInt64)length NS_UNAVAILABLE;
- (instancetype)initWithFilePath:(NSString *)filePath startPositionInAsset:(UInt64)position NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
