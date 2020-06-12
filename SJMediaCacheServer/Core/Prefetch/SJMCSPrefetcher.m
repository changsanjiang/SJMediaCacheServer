//
//  SJMCSPrefetcher.m
//  CocoaAsyncSocket
//
//  Created by BlueDancer on 2020/6/11.
//

#import "SJMCSPrefetcher.h"
#import "SJMCSHLSPrefetcher.h"
#import "SJMCSVODPrefetcher.h"
#import "MCSURLRecognizer.h"

@interface SJMCSPrefetcher ()
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic) NSUInteger preloadSize;
@end

@implementation SJMCSPrefetcher
//- (instancetype)initWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes;
//@property (nonatomic, weak, nullable) id<SJMCSPrefetcherDelegate> delegate;
//
//- (void)prepare;
//@property (nonatomic, readonly) float progress;
//@property (nonatomic, readonly) BOOL isClosed;
//@property (nonatomic, readonly) BOOL isDone;
//- (void)close;
+ (instancetype)prefetcherWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes {
    MCSResourceType type = [MCSURLRecognizer.shared resourceTypeForURL:URL];
    switch ( type ) {
        case MCSResourceTypeVOD:
            return [SJMCSVODPrefetcher.alloc initWithURL:URL preloadSize:bytes];
        case MCSResourceTypeHLS:
            return [SJMCSHLSPrefetcher.alloc initWithURL:URL preloadSize:bytes];
    }
    return nil;
}

- (void)prepare {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];

}

- (void)close {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];
}

- (BOOL)isClosed {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];

}

- (BOOL)isDone {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];

}

- (float)progress {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];

}
@end
