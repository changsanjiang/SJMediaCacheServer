//
//  MCSVODPrefetcher.h
//  CocoaAsyncSocket
//
//  Created by BlueDancer on 2020/6/11.
//

#import "MCSPrefetcher.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSVODPrefetcher : MCSPrefetcher

- (instancetype)initWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes;

@end

NS_ASSUME_NONNULL_END
