//
//  MCSPrefetcherManager.h
//  CocoaAsyncSocket
//
//  Created by BlueDancer on 2020/6/12.
//

#import "MCSPrefetcherDefines.h"
@protocol MCSPrefetchTask;

NS_ASSUME_NONNULL_BEGIN
@interface MCSPrefetcherManager : NSObject
+ (instancetype)shared;

@property (nonatomic) NSInteger maxConcurrentPrefetchCount;

- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL progress:(void(^_Nullable)(float progress))progressBlock completion:(void(^_Nullable)(NSError *_Nullable error))completionHandler;
- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL prefetchSize:(NSUInteger)prefetchSize;
- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL prefetchSize:(NSUInteger)prefetchSize progress:(void(^_Nullable)(float progress))progressBlock completion:(void(^_Nullable)(NSError *_Nullable error))completionHandler;
- (nullable id<MCSPrefetchTask>)prefetchWithURL:(NSURL *)URL prefetchFileCount:(NSUInteger)num progress:(void(^_Nullable)(float progress))progressBlock completion:(void(^_Nullable)(NSError *_Nullable error))completionHandler;

- (void)cancelAllPrefetchTasks;
@end
NS_ASSUME_NONNULL_END
