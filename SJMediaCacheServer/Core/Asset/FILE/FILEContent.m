//
//  FILEContent.m
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/11/24.
//

#import "FILEContent.h"

@implementation FILEContent
@synthesize readwriteCount = _readwriteCount;
@synthesize length = _length;
- (instancetype)initWithFilename:(NSString *)filename atOffset:(NSUInteger)offset {
    return [self initWithFilename:filename atOffset:offset length:0];
}

- (instancetype)initWithFilename:(NSString *)filename atOffset:(NSUInteger)offset length:(NSUInteger)length {
    self = [super init];
    if ( self ) {
        _filename = filename.copy;
        _offset = offset;
        _length = length;
    }
    return self;
}

- (void)didWriteDataWithLength:(NSUInteger)length {
    [self willChangeValueForKey:@"length"];
    dispatch_barrier_sync(dispatch_get_global_queue(0, 0), ^{
        _length += length;
    });
    [self didChangeValueForKey:@"length"];
}

- (long long)length {
    __block long long length = 0;
    dispatch_sync(dispatch_get_global_queue(0, 0), ^{
        length = _length;
    });
    return length;
}

- (NSInteger)readwriteCount {
    __block NSInteger readwriteCount = 0;
    dispatch_sync(dispatch_get_global_queue(0, 0), ^{
        readwriteCount = _readwriteCount;
    });
    return readwriteCount;
}

- (void)readwriteRetain {
    [self willChangeValueForKey:@"readwriteCount"];
    dispatch_barrier_sync(dispatch_get_global_queue(0, 0), ^{
        _readwriteCount += 1;
    });
    [self didChangeValueForKey:@"readwriteCount"];
}

- (void)readwriteRelease {
    [self willChangeValueForKey:@"readwriteCount"];
    dispatch_barrier_sync(dispatch_get_global_queue(0, 0), ^{
        if ( _readwriteCount > 0 )
            _readwriteCount -= 1;
    });
    [self didChangeValueForKey:@"readwriteCount"];
}
@end
