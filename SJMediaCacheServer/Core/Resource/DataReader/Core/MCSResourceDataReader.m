//
//  MCSResourceDataReader.m
//  Pods
//
//  Created by BlueDancer on 2020/8/5.
//

#import "MCSResourceDataReader.h"
#import "MCSResourceDataReaderSubclass.h"
#import "MCSQueue.h"
#import "NSFileHandle+MCS.h"
#import "MCSError.h"
#import "MCSLogger.h"

@implementation MCSResourceDataReader

- (instancetype)initWithResource:(MCSResource *)resource delegate:(id<MCSResourceDataReaderDelegate>)delegate {
    self = [super init];
    if ( self ) {
        _resource = resource;
        _delegate = delegate;
    }
    return self;
}

- (NSUInteger)availableLength {
    __block NSUInteger availableLength = 0;
    dispatch_sync(MCSDataReaderQueue(), ^{
        availableLength = _availableLength;
    });
    return availableLength;
}

- (NSUInteger)offset {
    __block NSUInteger offset = 0;
    dispatch_sync(MCSDataReaderQueue(), ^{
        offset = _range.location + _readLength;
    });
    return offset;
    
}

- (BOOL)isPrepared {
    __block BOOL isPrepared = NO;
    dispatch_sync(MCSDataReaderQueue(), ^{
        isPrepared = _isPrepared;
    });
    return isPrepared;
}

- (BOOL)isDone {
    __block BOOL isDone = NO;
    dispatch_sync(MCSDataReaderQueue(), ^{
        isDone = _isPrepared && (_readLength == _range.length);
    });
    return isDone;
}

- (void)prepare {
    dispatch_barrier_sync(MCSDataReaderQueue(), ^{
        if ( _isClosed || _isCalledPrepare )
            return;
        
        [self _prepare];
    });
}

- (nullable NSData *)readDataOfLength:(NSUInteger)param {
    __block NSData *data = nil;
    dispatch_barrier_sync(MCSDataReaderQueue(), ^{
        if ( _readLength == _range.length || _isClosed || !_isPrepared )
            return;
        
        if ( _availableLength <= _readLength )
            return;
        
        if ( _isSought ) {
            _isSought = NO;
            NSError *error = nil;
            NSUInteger offset = _startOffsetInFile + _readLength;
            if ( ![_reader seekToFileOffset:offset error:&error] ) {
                [self _onError:error];
                return;
            }
        }
        
        NSUInteger length = MIN(param, _availableLength - _readLength);
        NSError *error = nil;
        data = [_reader readDataOfLength:length error:&error];
        if ( error != nil ) {
            [self _onError:error];
            return;
        }
        
        NSUInteger readLength = data.length;
        if ( readLength == 0 )
            return;
        
        MCSDataReaderLog(@"%@: <%p>.read { offset: %lu, readLength: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)(_range.location + _readLength), (unsigned long)readLength);
        
        _readLength += readLength;
        
#ifdef DEBUG
        if ( _readLength == _range.length ) {
            MCSDataReaderLog(@"%@: <%p>.done \n", NSStringFromClass(self.class), self);
        }
#endif
    });
    return data;
}

- (BOOL)seekToOffset:(NSUInteger)offset {
    __block BOOL result = NO;
    dispatch_barrier_sync(MCSDataReaderQueue(), ^{
        if ( _isClosed || !_isPrepared )
            return;
        if ( offset < _range.location )
            return;
        if ( offset - _range.location > _availableLength )
            return;
        
        // offset     = range.location + readLength;
        // readLength = offset - range.location
        NSUInteger readLength = offset - _range.location;
        if ( readLength != _readLength ) {
            _isSought = YES;
            _readLength = readLength;
        }
        result = YES;
    });
    return result;
}

- (void)close {
    dispatch_barrier_sync(MCSDataReaderQueue(), ^{
        if ( _isClosed )
            return;
        [self _close];
    });
}

#pragma mark -

- (void)_onError:(NSError *)error {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];
}

- (void)_close {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];
}

- (void)_prepare {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];
}
@end
