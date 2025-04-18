//
//  HLSPrefetcher.h
//
//  Created by BlueDancer on 2020/6/11.
//


#import "MCSPrefetcherDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface HLSPrefetcher : NSObject<MCSPrefetcher>

- (instancetype)initWithURL:(NSURL *)URL prefetchSize:(NSUInteger)bytes delegate:(nullable id<MCSPrefetcherDelegate>)delegate;

/// prefetchFileCount 指加载 ts 的数量, 而且还会存在如下情况的处理:
///      - 当遇到`AES_KEY`时, 也会一并下载, 不计入数量.
- (instancetype)initWithURL:(NSURL *)URL prefetchFileCount:(NSUInteger)num delegate:(nullable id<MCSPrefetcherDelegate>)delegate;

- (instancetype)initWithURL:(NSURL *)URL delegate:(nullable id<MCSPrefetcherDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
