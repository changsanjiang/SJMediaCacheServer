//
//  MCSResourceFileDataReader.m
//  Pods
//
//  Created by BlueDancer on 2020/8/5.
//

#import "MCSResourceFileDataReader.h"
#import "MCSResourceDataReaderSubclass.h"
#import "MCSResource.h"

@interface MCSResourceFileDataReader ()
@property (nonatomic, copy, nullable) NSString *path;
@property (nonatomic, strong, nullable) MCSResourcePartialContent *content;
@end

@implementation MCSResourceFileDataReader
- (instancetype)initWithResource:(MCSResource *)resource inRange:(NSRange)range partialContent:(MCSResourcePartialContent *)content startOffsetInFile:(NSUInteger)startOffsetInFile  delegate:(id<MCSResourceDataReaderDelegate>)delegate {
    self = [super initWithResource:resource delegate:delegate];
    if ( self ) {
        _range = range;
        _content = content;
        [_resource willReadContent:content];
        _path = [resource filePathOfContent:content];
        _startOffsetInFile = startOffsetInFile;
    }
    return self;
}

- (void)dealloc {
    if ( !_isClosed ) [self _close];
}

- (void)_prepare {
    _isCalledPrepare = YES;
    
    MCSDataReaderLog(@"%@: <%p>.prepare { range: %@, file: %@.%@ };\n", NSStringFromClass(self.class), self, NSStringFromRange(_range), _path.lastPathComponent, NSStringFromRange(NSMakeRange(_startOffsetInFile, _range.length)));

    @try {
        _reader = [NSFileHandle fileHandleForReadingAtPath:_path];
        if ( _startOffsetInFile != 0 && _reader != nil ) {
            [_reader seekToFileOffset:_startOffsetInFile];
        }
    } @catch (NSException *exception) {
        [self _onError:[NSError mcs_exception:exception]];
    }
    
    if ( _reader == nil ) {
        [self _onError:[NSError mcs_fileNotExistError:@{
            MCSErrorUserInfoResourceKey : _resource,
            MCSErrorUserInfoRangeKey : [NSValue valueWithRange:_range]
        }]];
        return;
    }
    
    _availableLength = _range.length;
    _isPrepared = YES;
    
    dispatch_async(MCSDelegateQueue(), ^{
        [self->_delegate readerPrepareDidFinish:self];
        [self->_delegate reader:self hasAvailableDataWithLength:self->_availableLength];
    });
}

- (void)_onError:(NSError *)error {
    [self _close];
    dispatch_async(MCSDelegateQueue(), ^{
        [self->_delegate reader:self anErrorOccurred:error];
    });
}

- (void)_close {
    @try {
        [_reader closeFile];
        _reader = nil;
        _isClosed = YES;
        [_resource didEndReadContent:_content];
        MCSDataReaderLog(@"%@: <%p>.close;\n", NSStringFromClass(self.class), self);
    } @catch (NSException *exception) {
        
    }
}

@end
