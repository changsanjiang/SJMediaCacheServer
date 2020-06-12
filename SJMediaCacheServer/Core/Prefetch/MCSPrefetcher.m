//
//  MCSPrefetcher.m
//  CocoaAsyncSocket
//
//  Created by BlueDancer on 2020/6/11.
//

#import "MCSPrefetcher.h"
#import "MCSHLSPrefetcher.h"
#import "MCSVODPrefetcher.h"
#import "MCSURLRecognizer.h"

@interface MCSPrefetcher ()
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic) NSUInteger preloadSize;
@end

@implementation MCSPrefetcher
//- (instancetype)initWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes;
//@property (nonatomic, weak, nullable) id<MCSPrefetcherDelegate> delegate;
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
            return [MCSVODPrefetcher.alloc initWithURL:URL preloadSize:bytes];
        case MCSResourceTypeHLS:
            return [MCSHLSPrefetcher.alloc initWithURL:URL preloadSize:bytes];
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
