//
//  MCSPrefetcherSubclass.h
//  CocoaAsyncSocket
//
//  Created by BlueDancer on 2020/6/11.
//

#import "MCSPrefetcher.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSPrefetcher (Subclass)

@property (nonatomic, strong) NSURL *URL;
@property (nonatomic) NSUInteger preloadSize;

@end

NS_ASSUME_NONNULL_END
