//
//  SJResourceFileDataReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceFileDataReader.h"
#import "SJError.h"

@interface SJResourceFileDataReader()
@property (nonatomic) NSRange range;
@property (nonatomic) NSRange readRange;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSFileHandle *reader;

@property (nonatomic) NSUInteger offset;

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isClosed;
@property (nonatomic) BOOL isDone;
@end

@implementation SJResourceFileDataReader
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
    return [NSString stringWithFormat:@"SJResourceFileDataReader:<%p> { range: %@\n };", self, NSStringFromRange(_range)];
}

- (void)prepare {
    if ( _isClosed || _isCalledPrepare )
        return;
    
#ifdef DEBUG
    printf("%s: <%p>.prepare { range: %s, file: %s.%s };\n", NSStringFromClass(self.class).UTF8String, self, NSStringFromRange(_range).UTF8String, _path.lastPathComponent.UTF8String, NSStringFromRange(_readRange).UTF8String);
#endif
    
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
        
#ifdef DEBUG
        printf("%s: <%p>.read { offset: %lu, length: %lu };\n", NSStringFromClass(self.class).UTF8String, self, _offset, data.length);
        
        if ( _isDone ) {
            printf("%s: <%p>.done { range: %s , file: %s.%s };\n", NSStringFromClass(self.class).UTF8String, self, NSStringFromRange(_range).UTF8String, _path.lastPathComponent.UTF8String, NSStringFromRange(_readRange).UTF8String);
        }
#endif
        return data;
    } @catch (NSException *exception) {
        [self.delegate reader:self anErrorOccurred:[SJError errorForException:exception]];
    }
}

- (void)close {
    if ( _isClosed )
        return;
    
    _isClosed = YES;
    [_reader closeFile];
    _reader = nil;
    
#ifdef DEBUG
    printf("%s: <%p>.close;\n", NSStringFromClass(self.class).UTF8String, self);
#endif
}
@end
