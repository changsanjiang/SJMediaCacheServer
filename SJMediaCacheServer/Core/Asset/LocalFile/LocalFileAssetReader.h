//
//  LocalFileAssetReader.h
//  SJMediaCacheServer
//
//  Created by db on 2025/4/17.
//

#import "MCSInterfaces.h"
#import "MCSAssetDefines.h"
#import "MCSRequest.h"
@class LocalFileAsset;

NS_ASSUME_NONNULL_BEGIN

@interface LocalFileAssetReader : NSObject<MCSAssetReader>
- (instancetype)initWithAsset:(LocalFileAsset *)asset request:(MCSRequest *)request networkTaskPriority:(float)networkTaskPriority readDataDecryptor:(NSData *(^_Nullable)(NSURLRequest *request, NSUInteger offset, NSData *data))readDataDecryptor delegate:(id<MCSAssetReaderDelegate>)delegate;

- (void)prepare;
@property (nonatomic, readonly) MCSReaderStatus status;
@property (nonatomic, copy, readonly, nullable) NSData *(^readDataDecryptor)(NSURLRequest *request, NSUInteger offset, NSData *data);
@property (nonatomic, weak, readonly, nullable) id<MCSAssetReaderDelegate> delegate;
@property (nonatomic, strong, readonly, nullable) __kindof id<MCSAsset> asset;
@property (nonatomic, readonly) MCSDataType contentDataType;
@property (nonatomic, readonly) float networkTaskPriority;
@property (nonatomic, strong, readonly, nullable) id<MCSResponse> response;
@property (nonatomic, readonly) NSUInteger availableLength;
@property (nonatomic, readonly) NSUInteger offset;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (BOOL)seekToOffset:(NSUInteger)offset;
- (void)abortWithError:(nullable NSError *)error;

- (void)registerObserver:(id<MCSAssetReaderObserver>)observer;
- (void)removeObserver:(id<MCSAssetReaderObserver>)observer;
@end

NS_ASSUME_NONNULL_END
