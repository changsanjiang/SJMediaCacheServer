//
//  SJMCSPrefetcherSubclass.h
//  CocoaAsyncSocket
//
//  Created by BlueDancer on 2020/6/11.
//

#import "SJMCSPrefetcher.h"

NS_ASSUME_NONNULL_BEGIN

@interface SJMCSPrefetcher (Subclass)

@property (nonatomic, strong) NSURL *URL;
@property (nonatomic) NSUInteger preloadSize;

@end

NS_ASSUME_NONNULL_END
