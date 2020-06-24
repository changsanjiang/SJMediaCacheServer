//
//  MCSResourceFileDataReader.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResourceFileDataReader.h"
#import "MCSError.h"
#import "MCSLogger.h"

@interface MCSResourceFileDataReader()
@property (nonatomic) NSRange range;
@property (nonatomic) NSRange readRange;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSFileHandle *reader;

@property (nonatomic) NSUInteger offset;

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isClosed;
@property (nonatomic) BOOL isDone;
@end

@implementation MCSResourceFileDataReader
@synthesize delegate = _delegate;
@synthesize delegateQueue = _delegateQueue;

- (instancetype)initWithRange:(NSRange)range path:(NSString *)path readRange:(NSRange)readRange delegate:(id<MCSResourceDataReaderDelegate>)delegate delegateQueue:(dispatch_queue_t)queue {
    self = [super init];
    if ( self ) {
        _path = path.copy;
        _range = range;
        _readRange = readRange;
        _delegate = delegate;
        _delegateQueue = queue;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { range: %@\n };", NSStringFromClass(self.class), self, NSStringFromRange(_range)];
}

- (void)prepare {
    if ( _isClosed || _isCalledPrepare )
        return;
    
    _isCalledPrepare = YES;
    MCSLog(@"%@: <%p>.prepare { range: %@, file: %@.%@ };\n", NSStringFromClass(self.class), self, NSStringFromRange(_range), _path.lastPathComponent, NSStringFromRange(_readRange));

    _reader = [NSFileHandle fileHandleForReadingAtPath:_path];
    
    @try {
        [_reader seekToFileOffset:_readRange.location];
        _isPrepared = YES;
        
        dispatch_async(_delegateQueue, ^{
            [self.delegate readerPrepareDidFinish:self];
        });
    } @catch (NSException *exception) {
        [self _onError:[NSError mcs_exception:exception]];
    }
}

- (nullable NSData *)readDataOfLength:(NSUInteger)lengthParam {
    @try {
        if ( _isClosed || _isDone || !_isPrepared )
            return nil;
        
        NSUInteger length = MIN(lengthParam, _readRange.length - _offset);
        NSData *data = [_reader readDataOfLength:length];

        MCSLog(@"%@: <%p>.read { offset: %lu, readLength: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)_offset, (unsigned long)data.length);
        
        _offset += data.length;
        _isDone = _offset == _readRange.length;
                
#ifdef DEBUG
        if ( _isDone ) {
            MCSLog(@"%@: <%p>.done { range: %@ , file: %@.%@ };\n", NSStringFromClass(self.class), self, NSStringFromRange(_range), _path.lastPathComponent, NSStringFromRange(_readRange));
        }
#endif
        return data;
    } @catch (NSException *exception) {
        [self _onError:[NSError mcs_exception:exception]];
    }
}

- (void)close {
    if ( _isClosed )
        return;
    
    _isClosed = YES;
    [_reader closeFile];
    _reader = nil;
    
    MCSLog(@"%@: <%p>.close;\n", NSStringFromClass(self.class), self);
}

#pragma mark -

- (void)_onError:(NSError *)error {
    [self close];
    dispatch_async(_delegateQueue, ^{
        [self.delegate reader:self anErrorOccurred:error];
    });
}

- (void)setReader:(NSFileHandle *)reader {
    _reader = reader;
}
@end
