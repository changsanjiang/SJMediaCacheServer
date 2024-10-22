//
//  MCSAssetContent.h
//  SJMediaCacheServer
//
//  Created by 畅三江 on 2021/7/19.
//

#import "MCSReadwrite.h"
#import "MCSAssetDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSAssetContent : MCSReadwrite<MCSAssetContent>

/// Used for existing files
/// @param position 偏移量;
///        - 对于FILE文件, 表示内容在文件中的偏移量; 
///        - 对于HLS的资源文件:
///             - playlist 文件偏移量为0;
///             - aes key 文件偏移量为0;
///             - segment 文件偏移量通常为0, 不过如果通过标签 #EXT-X-BYTERANGE 指定了 sub-range, 则偏移量为这个 sub-range 的 location;
///
/// @param length 代表可读取的数据长度;
- (instancetype)initWithFilePath:(NSString *)filePath position:(UInt64)position length:(UInt64)length;
/// Used for new files
- (instancetype)initWithFilePath:(NSString *)filePath position:(UInt64)position;

- (nullable NSData *)readDataAtPosition:(UInt64)position capacity:(UInt64)capacity error:(out NSError **)error;
@property (nonatomic, readonly) UInt64 position;
@property (nonatomic, readonly) UInt64 length;
@property (nonatomic, strong, readonly, nullable) NSString *mimeType;

- (void)registerObserver:(id<MCSAssetContentObserver>)observer;
- (void)removeObserver:(id<MCSAssetContentObserver>)observer;

- (instancetype)initWithMimeType:(nullable NSString *)mimeType filePath:(NSString *)filePath position:(UInt64)position length:(UInt64)length;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end



@interface MCSAssetContent (Internal)
@property (nonatomic, strong, readonly) NSString *filePath;
@end
NS_ASSUME_NONNULL_END
