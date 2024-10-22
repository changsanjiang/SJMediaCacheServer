//
//  FILEPrefetcher.h
//  CocoaAsyncSocket
//
//  Created by BlueDancer on 2020/6/11.
//

#import "MCSPrefetcherDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface FILEPrefetcher : NSObject<MCSPrefetcher>

- (instancetype)initWithURL:(NSURL *)URL prefetchSize:(NSUInteger)bytes delegate:(nullable id<MCSPrefetcherDelegate>)delegate;

- (instancetype)initWithURL:(NSURL *)URL delegate:(nullable id<MCSPrefetcherDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
