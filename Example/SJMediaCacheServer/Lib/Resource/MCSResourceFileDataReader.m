//
//  MCSResourceFileDataReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
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
- (instancetype)initWithRange:(NSRange)range path:(NSString *)path readRange:(NSRange)readRange {
    self = [super init];
    if ( self ) {
        _path = path.copy;
        _range = range;
        _readRange = readRange;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { range: %@\n };", NSStringFromClass(self.class), self, NSStringFromRange(_range)];
}

- (void)prepare {
    if ( _isClosed || _isCalledPrepare )
        return;
    
    MCSLog(@"%@: <%p>.prepare { range: %@, file: %@.%@ };\n", NSStringFromClass(self.class), self, NSStringFromRange(_range), _path.lastPathComponent, NSStringFromRange(_readRange));

    _isCalledPrepare = YES;
    _reader = [NSFileHandle fileHandleForReadingAtPath:_path];
    [_reader seekToFileOffset:_readRange.location];
    
    [self.delegate readerPrepareDidFinish:self];
}

- (nullable NSData *)readDataOfLength:(NSUInteger)lengthParam {
    @try {
        if ( _isClosed || _isDone )
            return nil;
        
        NSUInteger length = MIN(lengthParam, _readRange.length - _offset);
        NSData *data = [_reader readDataOfLength:length];
        _offset += data.length;
        _isDone = _offset == _readRange.length;
        
        MCSLog(@"%@: <%p>.read { offset: %lu, readLength: %lu };\n", NSStringFromClass(self.class), self, _offset, data.length);
        
#ifdef DEBUG
        if ( _isDone ) {
            MCSLog(@"%@: <%p>.done { range: %@ , file: %@.%@ };\n", NSStringFromClass(self.class), self, NSStringFromRange(_range), _path.lastPathComponent, NSStringFromRange(_readRange));
        }
#endif
        return data;
    } @catch (NSException *exception) {
        [self.delegate reader:self anErrorOccurred:[NSError mcs_errorForException:exception]];
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
@end
