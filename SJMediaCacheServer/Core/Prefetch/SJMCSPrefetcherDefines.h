//
//  SJMCSPrefetcherDefines.h
//  Pods
//
//  Created by BlueDancer on 2020/6/11.
//

#ifndef SJMCSPrefetcherDefines_h
#define SJMCSPrefetcherDefines_h

#import <Foundation/Foundation.h>
@protocol SJMCSPrefetcherDelegate;

NS_ASSUME_NONNULL_BEGIN
@protocol SJMCSPrefetcher <NSObject>
@property (nonatomic, weak, nullable) id<SJMCSPrefetcherDelegate> delegate;

- (void)prepare;
- (void)close;

- (float)progress;
- (BOOL)isClosed;
- (BOOL)isDone;
@end

@protocol SJMCSPrefetcherDelegate <NSObject>
- (void)prefetcher:(id<SJMCSPrefetcher>)prefetcher progressDidChange:(float)progress;
- (void)prefetcher:(id<SJMCSPrefetcher>)prefetcher didCompleteWithError:(NSError *_Nullable)error;
@end
NS_ASSUME_NONNULL_END

#endif /* SJMCSPrefetcherDefines_h */
