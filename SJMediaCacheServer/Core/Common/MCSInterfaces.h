//
//  MCSInterfaces.h
//  SJMediaCacheServer
//
//  Created by 畅三江 on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#ifndef MCSInterfaces_h
#define MCSInterfaces_h
#import <Foundation/Foundation.h>
#import <SJUIKit/SJSQLiteTableModelProtocol.h>
#import "MCSDefines.h"
#import "NSURLRequest+MCS.h"

@protocol MCSResponse, MCSAsset, MCSAssetObserver, MCSConfiguration, MCSAssetReader, MCSRequest, MCSAssetContent, MCSDownloadResponse;
@protocol MCSProxyTaskDelegate, MCSAssetReaderDelegate;
@protocol MCSAssetReaderObserver;

NS_ASSUME_NONNULL_BEGIN
@protocol MCSProxyTask <NSObject>
- (instancetype)initWithRequest:(NSURLRequest *)request delegate:(id<MCSProxyTaskDelegate>)delegate;

- (void)prepare;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
@property (nonatomic, strong, readonly) NSURLRequest * request;
@property (nonatomic, strong, readonly, nullable) id<MCSResponse> response;
@property (nonatomic, readonly) NSUInteger offset;
@property (nonatomic, readonly) BOOL isPrepared;
@property (nonatomic, readonly) BOOL isDone;
- (void)close;
@end

@protocol MCSProxyTaskDelegate <NSObject>
- (void)task:(id<MCSProxyTask>)task didReceiveResponse:(id<MCSResponse>)response;
- (void)task:(id<MCSProxyTask>)task hasAvailableDataWithLength:(NSUInteger)length;
- (void)task:(id<MCSProxyTask>)task didAbortWithError:(nullable NSError *)error;
@end

#pragma mark -

@protocol MCSResponse <NSObject>
@property (nonatomic, readonly) NSUInteger totalLength; // 200请求时, NSUIntegerMax表示服务器未提供content-length;
@property (nonatomic, readonly) NSRange range; // 206请求时length不为0
@property (nonatomic, copy, readonly) NSString *contentType; // default is "application/octet-stream"
@end

#pragma mark -

@protocol MCSSaveable <SJSQLiteTableModelProtocol>

@end


@protocol MCSReadwriteReference <NSObject>
@property (nonatomic, readonly) NSInteger readwriteCount; // kvo

- (instancetype)readwriteRetain;
- (void)readwriteRelease;
@end

#pragma mark -
/// Before performing any operations on the asset's content,
/// you must first call `readwriteRetain` to lock the asset for modifications.
/// Once the operations are complete, you must call `readwriteRelease` to unlock it.
///
/// Example usage:
///
/// \code
/// id<MCSAsset> asset;
/// id<MCSAssetContent> content;
///
/// // Retain the asset for read/write operations
/// [asset readwriteRetain];
///
/// // Retrieve the content for the specified data type and position
/// content = [asset contentForDataType:xxx atPosition:xxx];
///
/// // Perform read operation
/// NSData *data = [content readDataAtPosition:xxx capacity:xxx error:xxx];
/// NSLog(@"%@", data);
///
/// // Release the content after read/write operation
/// [content readwriteRelease];
///
/// // Release the asset after all operations are done
/// [asset readwriteRelease];
/// \endcode
///
@protocol MCSAsset <MCSReadwriteReference, MCSSaveable>
- (instancetype)initWithName:(NSString *)name;
@property (nonatomic, readonly) NSInteger id;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, readonly) MCSAssetType type;
@property (nonatomic, copy, readonly) NSString *path;
@property (nonatomic, strong, readonly) id<MCSConfiguration> configuration;
@property (nonatomic, readonly) BOOL isStored;
@property (nonatomic, readonly) float completeness; // 完成度

- (void)prepare;
- (nullable id<MCSAssetContent>)createContentWithDataType:(MCSDataType)dataType response:(id<MCSDownloadResponse>)response error:(NSError **)error; // content readwrite is retained, should release after
- (nullable id<MCSAssetReader>)readerWithRequest:(id<MCSRequest>)request networkTaskPriority:(float)networkTaskPriority readDataDecryptor:(NSData *(^_Nullable)(NSURLRequest *request, NSUInteger offset, NSData *data))readDataDecryptor delegate:(nullable id<MCSAssetReaderDelegate>)delegate;
- (void)clear; // 清空本地文件缓存; 请谨慎调用;

- (void)registerObserver:(id<MCSAssetObserver>)observer;
- (void)removeObserver:(id<MCSAssetObserver>)observer;
@end

@protocol MCSAssetObserver <NSObject>
@optional
- (void)assetDidLoadMetadata:(id<MCSAsset>)asset; // 元数据加载完毕的回调
- (void)assetDidRead:(id<MCSAsset>)asset; // asset正在被读取数据
- (void)assetDidStore:(id<MCSAsset>)asset; // 所有相关数据存储完成的回调
- (void)assetWillClear:(id<MCSAsset>)asset; // 本地文件缓存被清空前的回调
- (void)assetDidClear:(id<MCSAsset>)asset; // 本地文件缓存被清空了
@end

@protocol MCSRequest <NSObject>

@end

#pragma mark -
 
@protocol MCSConfiguration <NSObject>

- (nullable NSDictionary<NSString *, NSString *> *)HTTPAdditionalHeadersForDataRequestsOfType:(MCSDataType)type;
- (void)setValue:(nullable NSString *)value forHTTPAdditionalHeaderField:(NSString *)key ofType:(MCSDataType)type;

@end
 
#pragma mark -

@protocol MCSAssetReader <NSObject>

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

@protocol MCSAssetReaderDelegate <NSObject>
- (void)reader:(id<MCSAssetReader>)reader didReceiveResponse:(id<MCSResponse>)response;
- (void)reader:(id<MCSAssetReader>)reader hasAvailableDataWithLength:(NSUInteger)length;
- (void)reader:(id<MCSAssetReader>)reader didAbortWithError:(nullable NSError *)error;
@end

@protocol MCSAssetReaderObserver <NSObject>
@optional
- (void)reader:(id<MCSAssetReader>)reader statusDidChange:(MCSReaderStatus)status;
@end


#pragma mark - Download

@protocol MCSDownloadResponse <MCSResponse>
@property (nonatomic, copy, readonly) NSURLRequest  *originalRequest;  /* NSURLSessionTask; may be nil if this is a stream task */
@property (nonatomic, copy, readonly) NSURLRequest  *currentRequest;   /* NSURLSessionTask; may differ from originalRequest due to http server redirection */
@property (nonatomic, readonly) NSInteger statusCode;
@property (nonatomic, copy, readonly, nullable) NSString *pathExtension;
@end

@protocol MCSDownloadTask <NSObject>
@property (readonly, copy) NSURLRequest  *originalRequest;  /* NSURLSessionTask; may be nil if this is a stream task */
@property (readonly, copy) NSURLRequest  *currentRequest;   /* NSURLSessionTask; may differ from originalRequest due to http server redirection */
- (void)cancel;
@end

@protocol MCSDownloadTaskDelegate <NSObject>
- (void)downloadTask:(id<MCSDownloadTask>)task didReceiveResponse:(id<MCSDownloadResponse>)response;
- (void)downloadTask:(id<MCSDownloadTask>)task didReceiveData:(NSData *)data;
- (void)downloadTask:(id<MCSDownloadTask>)task didCompleteWithError:(NSError *)error;
- (void)downloadTask:(id<MCSDownloadTask>)task willPerformHTTPRedirectionWithNewRequest:(NSURLRequest *)request;
@end

@protocol MCSDownloader <NSObject>
- (nullable id<MCSDownloadTask>)downloadWithRequest:(NSURLRequest *)request priority:(float)priority delegate:(id<MCSDownloadTaskDelegate>)delegate;
@end

NS_ASSUME_NONNULL_END

#endif /* MCSInterfaces_h */
