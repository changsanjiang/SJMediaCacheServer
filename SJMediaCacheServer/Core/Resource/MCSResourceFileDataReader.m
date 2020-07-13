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
#import "MCSFileManager.h"
#import "NSFileHandle+MCS.h"
#import "MCSResource.h"

@interface MCSResourceFileDataReader()
@property (nonatomic) NSRange range;
@property (nonatomic) NSRange readRange;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSFileHandle *reader;

@property (nonatomic) NSUInteger availableLength;
@property (nonatomic) NSUInteger readLength;

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isPrepared;
@property (nonatomic) BOOL isClosed;
@property (nonatomic) BOOL isDone;
@property (nonatomic) BOOL isSought;

@property (nonatomic, weak, nullable) MCSResource *resource;
@end

@implementation MCSResourceFileDataReader
@synthesize delegate = _delegate;

- (instancetype)initWithResource:(MCSResource *)resource range:(NSRange)range path:(NSString *)path readRange:(NSRange)readRange delegate:(id<MCSResourceDataReaderDelegate>)delegate {
    self = [super init];
    if ( self ) {
        _resource = resource;
        _range = range;
        _path = path.copy;
        _readRange = readRange;
        _delegate = delegate;
        _availableLength = readRange.length;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { range: %@\n };", NSStringFromClass(self.class), self, NSStringFromRange(_range)];
}

- (void)prepare {
    dispatch_sync(_resource.dataReaderOperationQueue, ^{
        @try {
            if ( self->_isClosed || self->_isCalledPrepare )
                return;
            
            self->_isCalledPrepare = YES;
            
            MCSLog(@"%@: <%p>.prepare { range: %@, file: %@.%@ };\n", NSStringFromClass(self.class), self, NSStringFromRange(self->_range), self->_path.lastPathComponent, NSStringFromRange(self->_readRange));
            
            self->_reader = [NSFileHandle fileHandleForReadingAtPath:self->_path];
            
            [self->_reader seekToFileOffset:self->_readRange.location];
            self->_isPrepared = YES;
            
            dispatch_async(self->_resource.delegateOperationQueue, ^{
                [self.delegate readerPrepareDidFinish:self];
            });
            
            NSUInteger length = self->_readRange.length;
            dispatch_async(self->_resource.delegateOperationQueue, ^{
                [self.delegate reader:self hasAvailableDataWithLength:length];
            });
        } @catch (NSException *exception) {
            [self _onError:[NSError mcs_exception:exception]];
        }
    });
}

- (nullable NSData *)readDataOfLength:(NSUInteger)lengthParam {
    __block NSData *data = nil;
    dispatch_sync(_resource.dataReaderOperationQueue, ^{
        @try {
            if ( self->_isClosed || self->_isDone || !self->_isPrepared )
                return;
            
            if ( self->_isSought ) {
                self->_isSought = NO;
                NSError *error = nil;
                NSUInteger offset = self->_readRange.location + self->_readLength;
                if ( ![self->_reader mcs_seekToFileOffset:offset error:&error] ) {
                    [self _onError:error];
                    return;
                }
            }
            
            NSUInteger length = MIN(lengthParam, self->_readRange.length - self->_readLength);
            data = [self->_reader readDataOfLength:length];
            
            NSUInteger readLength = data.length;
            if ( readLength == 0 )
                return;
            
            self->_readLength += readLength;
            self->_isDone = (self->_readLength == self->_readRange.length);
            
#ifdef DEBUG
            MCSLog(@"%@: <%p>.read { offset: %lu, readLength: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)(self->_range.location + self->_readLength), (unsigned long)readLength);
            if ( _isDone ) {
                MCSLog(@"%@: <%p>.done { range: %@ , file: %@.%@ };\n", NSStringFromClass(self.class), self, NSStringFromRange(self->_range), self->_path.lastPathComponent, NSStringFromRange(self->_readRange));
            }
#endif
        } @catch (NSException *exception) {
            [self _onError:[NSError mcs_exception:exception]];
        }
    });
    return data;
}

- (BOOL)seekToOffset:(NSUInteger)offset {
    __block BOOL result = NO;
    dispatch_sync(_resource.dataReaderOperationQueue, ^{
        if ( self->_isClosed || !self->_isPrepared )
            return;
        if ( !NSLocationInRange(offset - 1, self->_range) )
            return;
        
        // offset     = range.location + readLength;
        // readLength = offset - range.location
        NSUInteger readLength = offset - self->_range.location;
        if ( readLength != self->_readLength ) {
            self->_isSought = YES;
            self->_readLength = readLength;
            self->_isDone = (self->_readLength == self->_readRange.length);
        }
        result = YES;
    });
    return result;
}

- (void)close {
    dispatch_sync(_resource.dataReaderOperationQueue, ^{
        [self _close];
    });
}

#pragma mark -

- (NSUInteger)offset {
    __block NSUInteger offset = 0;
    dispatch_sync(_resource.dataReaderOperationQueue, ^{
        offset = self->_range.location + _readLength;
    });
    return offset;
}

- (BOOL)isPrepared {
    __block BOOL isPrepared = NO;
    dispatch_sync(_resource.dataReaderOperationQueue, ^{
        isPrepared = self->_isPrepared;
    });
    return isPrepared;
}

- (BOOL)isDone {
    __block BOOL isDone = NO;
    dispatch_sync(_resource.dataReaderOperationQueue, ^{
        isDone = self->_isDone;
    });
    return isDone;
}

#pragma mark -

- (void)_onError:(NSError *)error {
    [self _close];
    
    dispatch_async(_resource.delegateOperationQueue, ^{
        [self.delegate reader:self anErrorOccurred:error];
    });
}

- (void)_close {
    if ( _isClosed )
        return;
    
    @try {
        [_reader closeFile];
        _reader = nil;
        _isClosed = YES;
        
        MCSLog(@"%@: <%p>.close;\n", NSStringFromClass(self.class), self);
    } @catch (__unused NSException *exception) {
        
    }
}
@end
