//
//  SJMediaCacheServer.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//
//  Github: https://github.com/changsanjiang/SJMediaCacheServer.git
//
//  QQGroup: 930508201
//

#import <Foundation/Foundation.h>
#import "MCSPrefetcherDefines.h"
#import "MCSExporterDefines.h"
#import "MCSDefines.h"

NS_ASSUME_NONNULL_BEGIN
@interface SJMediaCacheServer : NSObject
+ (instancetype)shared;

/// Convert the given URL to the playback URL.
///
/// @param URL An instance of NSURL that references a media asset.
///
/// @return Returns the HTTP proxy URL if the proxy service is running; otherwise, it returns the original parameter URL.
/// If the provided URL is nil, this method will return nil.
///
/// @note This method may return nil if the input URL is nil.
///
/// \code
/// @implementation YourPlayerController {
///     AVPlayer *_player
/// }
///
/// - (instancetype)initWithURL:(NSURL *)URL {
///     self = [super init];
///     if ( self ) {
///         NSURL *playbackURL = [SJMediaCacheServer.shared playbackURLWithURL:URL];
///         _player = [AVPlayer playerWithURL:playbackURL];
///     }
///     return self;
/// }
///
/// - (void)play {
///     [SJMediaCacheServer.shared setActive:YES];
///     [_player play];
/// }
///
/// - (void)seekToTime:(NSTimeInterval)time {
///     [SJMediaCacheServer.shared setActive:YES];
///     [_player seekToTime:time];
/// }
/// @end
/// \endcode
///
- (nullable NSURL *)playbackURLWithURL:(NSURL *)URL; // 获取播放地址

@property (nonatomic, readonly, getter=isActive) BOOL active;

/// Set the active state of the socket proxy service.
///
/// @param active A Boolean value indicating whether to activate the proxy service.
/// When the app enters the background, the socket proxy service may be interrupted by the system.
/// Therefore, it is recommended to call this method to activate the proxy service when playback is in progress.
///
/// \code
/// @implementation YourPlayerController
/// - (void)play {
///     [SJMediaCacheServer.shared setActive:YES];
///     [_player play];
/// }
///
/// - (void)seekToTime:(NSTimeInterval)time {
///     [SJMediaCacheServer.shared setActive:YES];
///     [_player seekToTime:time];
/// }
/// @end
/// \endcode
///
- (void)setActive:(BOOL)active;
@end


@interface SJMediaCacheServer (Prefetch)

/// The maximum number of queued prefetch tasks that can execute at the same time.
///
/// The default value is 1.
@property (nonatomic) NSInteger maxConcurrentPrefetchCount;

/// Prefetch all data for the specified asset.
///
/// @param URL      An instance of NSURL that references a media asset.
///
/// @return The task to cancel the current prefetching, or nil if URL is nil.
///
/// @note This method preloads all data for the asset referenced by the provided URL. If the URL is nil,
///       the method will return nil.
- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL progress:(void(^_Nullable)(float progress))progressBlock completion:(void(^_Nullable)(NSError *_Nullable error))completionHandler; // 预加载所有数据

/// Prefetch a specified amount of data for the asset in the cache for future use. Assets are downloaded with low priority.
///
/// This method handles two types of assets: FILE and HLS.
/// - For FILE assets, it will preload the specified amount of data in bytes,
///   unless the file is smaller than the specified preload size.
/// - For HLS assets, it will attempt to preload multiple segment files
///   until the total size of the downloaded data is greater than or equal
///   to the specified preload size.
///
/// @param URL      An instance of NSURL that references a media asset.
/// @param bytes    The size of data to preload in bytes. This value is a hint, and the actual
///                 data downloaded may be larger than this size for HLS assets if multiple
///                 segments are fetched to meet the size requirement.
///
/// @return The task to cancel the current prefetching, or nil if URL is nil.
///
/// @note This method preloads a specified size of data for the asset referenced by the provided URL.
///       If the URL is nil, the method will return nil.
- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes; // 预加载指定大小的数据

/// Prefetch a specified amount of data for the asset in the cache for future use. Assets are downloaded with low priority.
///
/// This method handles two types of assets: FILE and HLS.
/// - For FILE assets, it will preload the specified amount of data in bytes,
///   unless the file is smaller than the specified preload size.
/// - For HLS assets, it will attempt to preload multiple segment files
///   until the total size of the downloaded data is greater than or equal
///   to the specified preload size.
///
/// This method also provides progress updates and a completion handler to
/// notify when the prefetching is completed.
///
/// @param URL            An instance of NSURL that references a media asset.
/// @param bytes          The size of data to preload in bytes. This value is a hint, and the actual
///                       data downloaded may be larger than this size for HLS assets if multiple
///                       segments are fetched to meet the size requirement.
/// @param progressBlock  A block that will be invoked when progress updates occur, reporting the
///                       current progress as a float value between 0.0 and 1.0.
/// @param completionHandler A block that will be invoked when the current prefetching is completed.
///                         If an error occurred, an error object indicating how the prefetch failed,
///                         otherwise nil.
///
/// @return The task to cancel the current prefetching, or nil if URL is nil.
///
/// @note This method is particularly useful for managing data prefetching based on asset types and
///       for providing user feedback through progress updates. If the URL is nil, the method will return nil.
///
- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes progress:(void(^_Nullable)(float progress))progressBlock completion:(void(^_Nullable)(NSError *_Nullable error))completionHandler; // 预加载指定大小的数据

/// Prefetch a designated number of files for the asset in the cache for future use. This method is primarily
/// intended for HLS resources, as M3U8 playlists typically contain multiple segment files.
///
/// The designated number of preloaded files must be greater than 0. However, the actual number of segment
/// files cached may be less than the specified number, as the number of segment.ts files in the M3U8
/// playlist can be fewer than the provided value. For HLS assets, this method will download the designated
/// number of segment files to be cached, if available. If the provided URL corresponds to a FILE resource,
/// since FILE only contains a single file, the entire FILE resource will be cached.
///
/// This method also provides progress updates and a completion handler to notify when the prefetching is completed.
///
/// @param URL            An instance of NSURL that references a media asset.
/// @param count          The designated number of preloaded segment files. This value must be greater than 0.
/// @param progressBlock  A block that will be invoked when progress updates occur, reporting the
///                       current progress as a float value between 0.0 and 1.0.
/// @param completionHandler A block that will be invoked when the current prefetching is completed.
///                         If an error occurred, an error object indicating how the prefetch failed,
///                         otherwise nil.
///
/// @return The task to cancel the current prefetching, or nil if URL is nil.
///
/// @note This method is useful for efficiently preloading multiple segment files for HLS assets,
///       ensuring a smoother playback experience while also managing FILE resources as needed.
///       If the URL is nil, the method will return nil.
///
- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL preloadFileCount:(NSUInteger)count progress:(void(^_Nullable)(float progress))progressBlock completion:(void(^_Nullable)(NSError *_Nullable error))completionHandler; // 预加载指定个数的文件

/// Cancels all queued and executing prefetch tasks.
///
- (void)cancelAllPrefetchTasks; // 取消所有的预加载任务

@end


@interface SJMediaCacheServer (Request)
/// The session configuration used when making requests to the remote server.
/// This configuration allows users to customize various aspects of the network session, such as timeout intervals,
/// caching policies, and protocol settings. Users can set this configuration to modify how the requests are handled.
///
/// @note This property must be set before the proxy service is started(active); otherwise, the configuration will not take effect.
///       If not set, the default session configuration will be used.
///
/// \code
/// // Example of setting a custom session configuration:
/// NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
/// config.timeoutIntervalForRequest = 30.0; // Set a custom timeout
/// self.sessionConfiguration = config;
/// \endcode
///
@property (nonatomic, strong, nullable) NSURLSessionConfiguration *sessionConfiguration;

/// A block that is invoked when the local proxy server makes a request to the remote server.
/// The block provides the request object, allowing users to modify it directly, such as adding custom headers.
///
/// @property requestHandler A block that accepts a mutable request object for modification.
///                          The user can add headers or make other adjustments to the request.
///                          Since the request is mutable, no return value is needed.
///
/// @param request   A mutable NSURLRequest object representing the outgoing request to the remote server.
///
/// \code
/// // Example of adding a custom header:
/// self.requestHandler = ^(NSMutableURLRequest *request) {
///     [request addValue:@"YourHeaderValue" forHTTPHeaderField:@"YourHeaderField"];
/// };
/// \endcode
///
@property (nonatomic, copy, nullable) void (^requestHandler)(NSMutableURLRequest *request); // 为下载请求添加请求头或做一些其他事情

/// Configures a custom HTTP header field for a specified asset URL, targeting specific data types
/// such as AES keys or segment files in an HLS playlist.
///
/// @param URL     An NSURL that references the media asset for which the HTTP header field should be set.
/// @param field   The name of the HTTP header field to set. This field should be a valid HTTP header field name.
/// @param value   The value to set for the specified HTTP header field. Pass nil to remove the header field.
/// @param type    The type of data associated with the URL, such as AES key or segment file, represented by the MCSDataType enumeration.
///
/// \code
/// // For example, to append a custom HTTP header field to all requests related to an HLS asset
/// // (including requests for AES keys or segment.ts files):
/// [self setHTTPHeaderField:@"YourHeaderField" withValue:@"YourHeaderValue" forAssetURL:assetURL ofType:MCSDataTypeHLS];
/// \endcode
///
- (void)setHTTPHeaderField:(NSString *)field withValue:(nullable NSString *)value forAssetURL:(NSURL *)URL ofType:(MCSDataType)type;

/// Retrieves the custom HTTP headers that have been configured for a specified asset URL,
/// targeting specific data types such as AES keys or segment files in an HLS playlist.
///
/// @param URL   An NSURL that references the media asset for which the HTTP headers should be retrieved.
/// @param type  The type of data associated with the URL, such as AES key or segment file, represented by the MCSDataType enumeration.
///
/// @return A dictionary containing the configured HTTP headers for the specified asset URL and data type,
///         where the keys are the header field names and the values are the corresponding header values.
///         Returns nil if no headers are configured.
///
/// \code
/// // For example, retrieve the HTTP headers set for HLS segment.ts requests:
/// NSDictionary *headers = [self HTTPAdditionalHeadersForAssetURL:assetURL ofType:MCSDataTypeHLSSegment];
/// \endcode
///
- (nullable NSDictionary<NSString *, NSString *> *)HTTPAdditionalHeadersForAssetURL:(NSURL *)URL ofType:(MCSDataType)type;

/// A block that is called when the task has finished collecting metrics.
/// This block allows external users to handle the metrics collected during the task's execution.
/// If not set, no additional action is taken.
///
/// @param session The session containing the task that finished collecting metrics.
/// @param task    The task that finished collecting metrics.
/// @param metrics The collected metrics for the task, containing detailed timing information.
///
/// \code
/// self.metricsHandler = ^(NSURLSession *session, NSURLSessionTask *task, NSURLSessionTaskMetrics *metrics) {
///     // Handle the collected metrics here, e.g., log them or send them to a server.
/// };
/// \endcode
///
@property (nonatomic, copy, nullable) void (^metricsHandler)(NSURLSession *session, NSURLSessionTask *task, NSURLSessionTaskMetrics *metrics);

@property (nonatomic, copy, nullable) void (^proxyTaskAbortCallback)(NSURLRequest *request, NSError *_Nullable error);
@end


@interface SJMediaCacheServer (Convert)
/// A block that determines the asset type (e.g., HLS or FILE) for a given URL.
/// This block allows users to provide custom logic to resolve the type of media asset based on the URL.
/// If not set, the default behavior will be used to resolve the asset type.
///
/// @param URL The URL for which the asset type needs to be resolved.
/// @return The asset type as an MCSAssetType value, such as HLS or FILE.
///
/// @note This block is useful for scenarios where the asset type cannot be inferred from the URL alone,
///       allowing users to implement custom logic for determining the asset type.
///
/// \code
/// // Example of setting a custom resolveAssetType block:
/// self.resolveAssetType = ^MCSAssetType(NSURL *URL) {
///     if ([URL.pathExtension isEqualToString:@"m3u8"]) {
///         return MCSAssetTypeHLS;
///     }
///     return MCSAssetTypeFILE;
/// };
/// \endcode
///
@property (nonatomic, copy, nullable) MCSAssetType (^resolveAssetType)(NSURL *URL); // 返回这个URL指向的资源类型

/// A block that resolves the unique asset identifier for a given URL.
/// This is particularly useful when URLs contain dynamic or authentication parameters, but still refer to the same asset.
/// Users can provide custom logic to generate a consistent identifier for such URLs (e.g., an MD5 hash).
/// If this block is not set, the default behavior for resolving asset identifiers will be used.
///
/// @param URL The URL for which the asset identifier needs to be resolved.
/// @return A unique identifier (e.g., a string) that represents the asset. If multiple URLs refer to the same asset, this block should return the same identifier for those URLs.
///
/// @note This block helps ensure that different variations of the same URL (e.g., with different authentication tokens) are recognized as the same asset.
///       Custom logic can be applied to strip irrelevant query parameters or to compute a consistent identifier.
///
/// \code
/// // Example of setting a custom resolveAssetIdentifier block:
/// self.resolveAssetIdentifier = ^NSString *(NSURL *URL) {
///     NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
///     components.query = nil; // ignore query parameters for identifier purposes
///     return components.URL.absoluteString;
/// };
/// \endcode
///
@property (nonatomic, copy, nullable) NSString *(^resolveAssetIdentifier)(NSURL *URL); // URL参数不固定时, 请设置该block返回一个唯一标识符

/// A block that handles data encryption before it is written to the cache.
/// This block allows for custom encryption logic to be applied to the data
/// before it is stored in the cache.
///
/// @note The length of the data must remain the same after encryption to ensure
///       correct handling of cache offsets and file integrity.
///
/// @param request The original NSURLRequest for which the data is being written.
/// @param offset  The offset within the file where the data will be written.
/// @param data    The data to be encrypted before writing to the cache.
/// @return The encrypted NSData to be written. The length of the returned data must
///         match the input data.
///
/// \code
/// self.writeDataEncryptor = ^NSData *(NSURLRequest *request, NSUInteger offset, NSData *data) {
///     // Implement your encryption logic here
///     // The encryptedData.length must equal to data.length
///     return encryptedData;
/// };
/// \endcode
///
@property (nonatomic, copy, nullable) NSData *(^writeDataEncryptor)(NSURLRequest *request, NSUInteger offset, NSData *data); // 对下载的数据进行加密

/// A block that handles data decryption after it is read from the cache.
/// This block allows for custom decryption logic to be applied to the data
/// after it is retrieved from the cache.
///
/// @note The length of the data must remain the same after decryption to ensure
///       correct handling of cache offsets and data integrity.
///
/// @param request The original NSURLRequest for which the data is being read.
/// @param offset  The offset within the file where the data is being read.
/// @param data    The encrypted data read from the cache to be decrypted.
/// @return The decrypted NSData to be used. The length of the returned data must
///         match the input data.
///
/// \code
/// self.readDataDecryptor = ^NSData *(NSURLRequest *request, NSUInteger offset, NSData *data) {
///     // Implement your decryption logic here
///     // The decryptedData.length must equal to data.length
///     return decryptedData;
/// };
/// \endcode
///
@property (nonatomic, copy, nullable) NSData *(^readDataDecryptor)(NSURLRequest *request, NSUInteger offset, NSData *data); // 对读取的数据进行解密
@end


@interface SJMediaCacheServer (Log)

/// Whether to enable console logging, available only in debug mode.
/// No logs will be generated in release mode.
///
///     If set to YES, logs will be output to the console.
///     The default value is NO.
///
/// @note This setting is only effective in debug mode.
///       In release mode, logs will not be generated regardless of this setting.
///
@property (nonatomic, getter=isEnabledConsoleLog) BOOL enabledConsoleLog; // 是否开启控制日志

/// Specifies the logging options to determine which components should log their activities.
///
///     The default value is MCSLogOptionDefault, which includes ProxyTask, Prefetcher, and Heartbeat logs.
///     You can combine multiple options using the bitwise OR operator to enable logs from multiple components.
///
/// @note Use `MCSLogOptionAll` to enable logs from all components.
///
@property (nonatomic) MCSLogOptions logOptions; // 设置日志选项, 以提供更加详细的日志.

/// Specifies the logging level for the system.
///
///     MCSLogLevelDebug provides detailed logging for debugging purposes.
///     MCSLogLevelError only outputs error messages.
///
///     The default value is MCSLogLevelDebug.
///
/// @note This can be used to control the verbosity of logs.
///
@property (nonatomic) MCSLogLevel logLevel;
@end


@interface SJMediaCacheServer (Cache)
/// The maximum number of assets the cache should hold.
///
///     If set to 0, there is no limit on the number of cached assets. The default value is 0.
///     This is a soft limit, meaning the system may exceed this number temporarily
///     depending on asset usage patterns and removal policies.
///
/// @note If the limit is exceeded, cached assets may be removed to free space based on their usage.
///
@property (nonatomic) NSUInteger cacheCountLimit; // 个数限制

/// The maximum amount of time to keep an asset in the cache, in seconds.
///
///     If set to 0, cached assets will not expire based on age. The default value is 0.
///
/// @note Assets may be removed from the cache to free up space based on their age limit.
///       The actual removal may occur instantly, later, or never, depending on asset usage and conditions.
///
@property (nonatomic) NSTimeInterval cacheMaxDiskAge; // 保存时长限制

/// The maximum size of the disk cache, in bytes.
///
///     If set to 0, there is no limit on the cache size. The default value is 0.
///
/// @note If the cache size exceeds this limit, cached assets may be removed to reduce the total cache size.
///       This removal process depends on asset usage and priority.
///
@property (nonatomic) NSUInteger cacheMaxDiskSize; // 缓存占用的磁盘空间限制

/// The minimum free disk space, in bytes, that should be reserved on the device.
///
///     If the available disk space is less than or equal to this value, cached assets will be removed
///     to free up space on the device.
///
///     If set to 0, no reserved disk space will be enforced. The default value is 0.
///
/// @note This setting ensures that the device has a minimum amount of free space available,
///       and cached assets may be removed accordingly to maintain this free space.
///
@property (nonatomic) NSUInteger cacheReservedFreeDiskSpace; // 剩余磁盘空间限制

/// Returns the total number of bytes used by all caches, excluding protected assets.
///
///     This property provides the cumulative size of all cached assets in bytes,
///     and it is updated automatically as assets are added or removed from the cache.
///     Protected assets (e.g., exported assets) are not included in this calculation.
///
/// @return The total size, in bytes, of all removable cached assets.
///
@property (nonatomic, readonly) UInt64 countOfBytesAllCaches; // 可被删除的缓存所占用的大小

/// Removes the cache of the specified URL.
///
/// If the cache for an asset is protected (e.g., an exported asset), it will not be removed.
///
- (BOOL)removeCacheForURL:(NSURL *)URL; // 删除某个缓存

/// Removes all unprotected caches for assets.
///
/// If the cache for an asset is protected (e.g., an exported asset), it will not be removed.
///
/// This method may block the calling thread until the file deletion is finished.
///
/// Additionally, this method will cancel all reading or writing operations associated with the caches.
///
- (void)removeAllCaches;

/// Checks if all data associated with the asset for the given URL has been fully cached.
///
/// This method returns YES if all components of the specified asset (including AES keys, segments,
/// etc. for HLS types) have been successfully stored locally. For FILE types, it checks if the
/// single file is completely cached. If any part of the asset is not cached, it will return NO.
///
/// @param URL The NSURL representing the asset to check.
///
/// @return YES if all data associated with the asset is fully cached; otherwise, NO.
///
/// @note This method may involve checking the cache state and may not
///       be instantaneous, depending on the caching implementation and
///       the asset's current state.
- (BOOL)isFullyStoredAssetForURL:(NSURL *)URL; // 查询指定URL的Asset的所有数据是否已完整缓存;
@end

/// What's the difference between export and prefetch?
///
/// Exported assets are protected and cannot be deleted by the cache management system. Once the export process begins for an asset,
/// it becomes protected, ensuring that the data remains available even if the cache exceeds limits or the system enforces cleanup policies.
///
/// In contrast, prefetched assets are managed by the MCSCacheManager. These assets are stored temporarily but are not protected.
/// They may be deleted by the cache management system based on usage patterns, space constraints, or other cache management policies.
///
/// If you want to remove an exported asset, you must use the MCSExporterManager to do so. Prefetched assets, however, are automatically
/// managed by the MCSCacheManager and may be removed without direct user intervention.
///
@interface SJMediaCacheServer (Export)

/// Register an observer to listen for export events.
///
/// You do not need to unregister the observer. If you forget or are unable to remove the observer, the manager will remove it automatically.
///
- (void)registerExportObserver:(id<MCSExportObserver>)observer; // 监听导出相关的事件
 
/// Remove the export observer.
///
/// You do not need to manually unregister the observer. If the observer is no longer needed, it will be removed automatically.
///
- (void)removeExportObserver:(id<MCSExportObserver>)observer; // 移除监听

/// The maximum number of export tasks that can execute concurrently.
///
///     The default value is 1.
///
///     This setting indirectly affects `maxConcurrentPrefetchCount`, meaning that the total number
///     of concurrent export and prefetch tasks cannot exceed this limit.
///
@property (nonatomic) NSInteger maxConcurrentExportCount;

@property (nonatomic, strong, readonly, nullable) NSArray<id<MCSExporter>> *allExporters;

- (nullable NSArray<id<MCSExporter>> *)exportersForMask:(MCSExportStatusQueryMask)mask; // 查询

/// Starts exporting the asset associated with the given URL.
///
///     If the asset is not yet exported, a new export task will be created.
///
/// @param URL The URL of the asset to export.
///
/// @return The exporter for the asset, or nil if the asset cannot be exported.
///
/// \code
///     [SJMediaCacheServer.shared registerExportObserver:self];
///
///     id<MCSExporter> exporter = [SJMediaCacheServer.shared exportAssetWithURL:URL];
///     [exporter resume];
/// \endcode
///
- (nullable id<MCSExporter>)exportAssetWithURL:(NSURL *)URL;

/// Starts exporting the asset associated with the given URL, with an option to resume immediately.
///
///     If the asset is not yet exported, a new export task will be created.
///     If `shouldResume` is YES, the export will start immediately after creating the task.
///
/// @param URL The URL of the asset to export.
/// @param shouldResume A boolean indicating whether to automatically resume the export after creating the task.
///
/// @return The exporter for the asset, or nil if the asset cannot be exported.
///
- (nullable id<MCSExporter>)exportAssetWithURL:(NSURL *)URL shouldResume:(BOOL)shouldResume; // 获取exporter, 如果不存在将会创建.
 
- (MCSExportStatus)exportStatusForURL:(NSURL *)URL; // 当前状态
- (float)exportProgressForURL:(NSURL *)URL; // 当前进度 

/// Synchronize the cache progress to the export task associated with the given asset URL.
///
///     This method updates the exporter's progress to reflect the latest cached data.
///     It can be used when the cache has progressed independently of the export task.
///
/// @param URL The URL of the asset for which to synchronize the exporter.
///
- (void)synchronizeProgressForExporterWithURL:(NSURL *)URL; // 同步进度

/// Synchronize the progress of all in-memory exporters.
///
///     This method updates the progress of all active export tasks to reflect the latest cached data.
///     Use this method when multiple exporters may need progress synchronization.
///
- (void)synchronizeProgressForExporters; // 同步内存中的exporter的进度

@property (nonatomic, readonly) UInt64 countOfBytesAllExportedAssets; // 返回导出资源占用的缓存大小

/// Remove both in-progress and completed exported assets for the given URL.
///
/// @param URL The URL of the asset to remove.
///
- (void)removeExportAssetWithURL:(NSURL *)URL;

/// Remove all in-progress and completed exported assets.
///
- (void)removeAllExportAssets;
@end
NS_ASSUME_NONNULL_END
