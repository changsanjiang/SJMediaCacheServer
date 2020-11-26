//
//  HLSContentTs.m
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/11/25.
//

#import "HLSContentTs.h"

@implementation HLSContentTs
@synthesize readwriteCount = _readwriteCount;
@synthesize length = _length;
- (instancetype)initWithName:(NSString *)name filename:(NSString *)filename totalLength:(long long)totalLength {
    return [self initWithName:name filename:filename totalLength:totalLength length:0];
}

- (instancetype)initWithName:(NSString *)name filename:(NSString *)filename totalLength:(long long)totalLength length:(long long)length {
    self = [super init];
    if ( self ) {
        _name = name.copy;
        _filename = filename.copy;
        _totalLength = totalLength;
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
