//
//  MCSAssetContentReader.h
//  SJMediaCacheServer
//
//  Created by 畅三江 on 2021/7/19.
//

#import "MCSInterfaces.h"
#import "MCSAssetDefines.h"

NS_ASSUME_NONNULL_BEGIN
@interface MCSAssetContentReader : NSObject<MCSAssetContentReader>
- (instancetype)initWithAsset:(id<MCSAsset>)asset delegate:(id<MCSAssetContentReaderDelegate>)delegate;
- (void)prepare;
@property (nonatomic, strong, readonly, nullable) __kindof id<MCSAssetContent> content;
@property (nonatomic, readonly) NSRange range; // range in asset
@property (nonatomic, readonly) UInt64 availableLength;
@property (nonatomic, readonly) UInt64 offset;
@property (nonatomic, readonly) MCSReaderStatus status;
- (nullable NSData *)readDataOfLength:(UInt64)length;
- (BOOL)seekToOffset:(UInt64)offset;
- (void)abortWithError:(nullable NSError *)error;
@end


@interface MCSAssetContentReader (Internal)
/// 实现类在准备好 content 之后, 调用该方法通知抽象类;
///
/// 实现类通知抽象类已准备好 content;
/// 调用前请对 content 做一次 readwriteRetain 操作, 防止被提前 release; 之后不需要外部调用 release, 抽象类会在读取操作结束后做一次 release 操作;
- (void)contentDidReady:(id<MCSAssetContent>)content range:(NSRange)range;
@end

@interface MCSAssetContentReader (Subclass)
- (void)prepareContent; /// 实现类准备内容
@end

@interface MCSAssetContentReader (Hooks)
- (void)didAbortWithError:(nullable NSError *)error;
- (void)didClear;
@end

@interface MCSAssetFileContentReader : MCSAssetContentReader

- (instancetype)initWithAsset:(id<MCSAsset>)asset fileContent:(id<MCSAssetContent>)content rangeInAsset:(NSRange)range delegate:(id<MCSAssetContentReaderDelegate>)delegate;

@end


@interface MCSAssetHTTPContentReader : MCSAssetContentReader

- (instancetype)initWithAsset:(id<MCSAsset>)asset request:(NSURLRequest *)request networkTaskPriority:(float)priority dataType:(MCSDataType)dataType delegate:(id<MCSAssetContentReaderDelegate>)delegate;

- (instancetype)initWithAsset:(id<MCSAsset>)asset request:(NSURLRequest *)request rangeInAsset:(NSRange)range contentReadwrite:(nullable id<MCSAssetContent>)content /* 如果content不存在将会通过asset进行创建 */ networkTaskPriority:(float)priority dataType:(MCSDataType)dataType delegate:(id<MCSAssetContentReaderDelegate>)delegate;
@end
NS_ASSUME_NONNULL_END
