//
//  MCSVODPrefetcher.m
//  CocoaAsyncSocket
//
//  Created by BlueDancer on 2020/6/11.
//

#import "MCSVODPrefetcher.h"
#import "MCSLogger.h"
#import "MCSResourceManager.h"
#import "NSURLRequest+MCS.h"
#import "MCSPrefetcherSubclass.h"

@interface MCSVODPrefetcher () <NSLocking, MCSResourceReaderDelegate> {
    NSRecursiveLock *_lock;
}
@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isPrepared;
@property (nonatomic) BOOL isClosed;
 
@property (nonatomic, strong, nullable) id<MCSResourceReader> reader;
@property (nonatomic) NSUInteger offset;
@end

@implementation MCSVODPrefetcher
- (instancetype)initWithURL:(NSURL *)URL preloadSize:(NSUInteger)bytes {
    self = [super init];
    if ( self ) {
        self.URL = URL;
        self.preloadSize = bytes;
        _lock = NSRecursiveLock.alloc.init;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { preloadSize: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)self.preloadSize];
}

- (void)dealloc {
    MCSLog(@"%@: <%p>.dealloc;\n", NSStringFromClass(self.class), self);
}

- (void)prepare {
    [self lock];
    @try {
        if ( _isClosed || _isCalledPrepare )
            return;
        
        MCSLog(@"%@: <%p>.prepare { preloadSize: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)self.preloadSize);

        _isCalledPrepare = YES;
        
        NSURLRequest *request = [NSURLRequest mcs_requestWithURL:self.URL range:NSMakeRange(0, self.preloadSize)];
        _reader = [MCSResourceManager.shared readerWithRequest:request];
        _reader.delegate = self;
        [_reader prepare];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)close {
    [self lock];
    @try {
        if ( _isClosed )
            return;
        
        _isClosed = YES;
        [_reader close];
        
        MCSLog(@"%@: <%p>.close { preloadSize: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)self.preloadSize);
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (float)progress {
    [self lock];
    @try {
        return _reader.isPrepared ? _offset * 1.0 / _reader.response.contentRange.length : 0;
    } @catch (__unused NSException *exception) {
            
    } @finally {
        [self unlock];
    }
}

- (BOOL)isClosed {
    [self lock];
    @try {
        return _reader.isClosed;
    } @catch (__unused NSException *exception) {
            
    } @finally {
        [self unlock];
    }

}

- (BOOL)isDone {
    [self lock];
    @try {
        return _reader.isReadingEndOfData;
    } @catch (__unused NSException *exception) {
            
    } @finally {
        [self unlock];
    }
}

#pragma mark -

- (void)readerPrepareDidFinish:(id<MCSResourceReader>)reader {
    [self readerHasAvailableData:reader];
}

- (void)readerHasAvailableData:(id<MCSResourceReader>)reader {
    [self lock];
    @try {
        while (true) {
            @autoreleasepool {
                NSData *data = [_reader readDataOfLength:1 * 1024 * 1024];
                if ( data.length == 0 )
                    break;
                
                _offset += data.length;
                
                float progress = _offset * 1.0 / reader.response.contentRange.length;
                [self.delegate prefetcher:self progressDidChange:progress];
                
                MCSLog(@"%@: <%p>.preload { preloadSize: %lu, progress: %f };\n", NSStringFromClass(self.class), self, (unsigned long)self.preloadSize, progress);

                if ( _reader.isReadingEndOfData ) {
                    MCSLog(@"%@: <%p>.done { preloadSize: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)self.preloadSize);
                    [self close];
                    [self.delegate prefetcher:self didCompleteWithError:nil];
                    break;
                }
            }
        }
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)reader:(id<MCSResourceReader>)reader anErrorOccurred:(NSError *)error {
    MCSLog(@"%@: <%p>.error { preloadSize: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)self.preloadSize);

    [self close];
    [self.delegate prefetcher:self didCompleteWithError:error];
}

#pragma mark -

- (void)lock {
    [_lock lock];
}

- (void)unlock {
    [_lock unlock];
}

@end
