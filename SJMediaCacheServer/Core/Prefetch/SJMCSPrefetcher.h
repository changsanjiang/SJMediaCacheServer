//
//  SJMCSPrefetcher.h
//  CocoaAsyncSocket
//
//  Created by BlueDancer on 2020/6/11.
//

#import "SJMCSPrefetcherDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SJMCSPrefetcher : NSObject<SJMCSPrefetcher>
+ (instancetype)prefetcherWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes;
@property (nonatomic, weak, nullable) id<SJMCSPrefetcherDelegate> delegate;

@property (nonatomic, strong, readonly) NSURL *URL;
@property (nonatomic, readonly) NSUInteger preloadSize;

- (void)prepare;
- (float)progress;
- (BOOL)isClosed;
- (BOOL)isDone;
- (void)close;
@end

NS_ASSUME_NONNULL_END
