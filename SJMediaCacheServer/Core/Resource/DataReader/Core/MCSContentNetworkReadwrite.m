//
//  MCSContentNetworkReadwrite.m
//  Pods
//
//  Created by BlueDancer on 2020/8/24.
//

#import "MCSContentNetworkReadwrite.h"
#import "NSFileHandle+MCS.h"
#import "MCSQueue.h"
#import "MCSError.h"

@interface MCSContentNetworkReadwrite ()
@property (nonatomic, strong) NSFileHandle *writer;
@property (nonatomic, strong) NSMutableData *memoryData;
@property (nonatomic) NSUInteger readLength;
@end

@implementation MCSContentNetworkReadwrite
static dispatch_queue_t serial_write_queue = nil;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        serial_write_queue = dispatch_queue_create("mcs.MCSContentNetworkReadwriteWriteQueue", DISPATCH_QUEUE_SERIAL);
    });
}

+ (nullable instancetype)readerWithPath:(NSString *)path delegate:(id<MCSContentNetworkReadwriteDelegate>)delegate {
    NSFileHandle *writer = [NSFileHandle fileHandleForWritingAtPath:path];
    if ( writer == nil )
        return nil;
    
    return [MCSContentNetworkReadwrite.alloc initWithWriter:writer delegate:delegate];
}

- (instancetype)initWithWriter:(NSFileHandle *)writer delegate:(id<MCSContentNetworkReadwriteDelegate>)delegate {
    self = [super init];
    if ( self ) {
        _writer = writer;
        _memoryData = NSMutableData.data;
        _delegate = delegate;
    }
    return self;
}

- (void)dealloc {
    @try {
        [_writer synchronizeFile];
        [_writer closeFile];
    } @catch (__unused NSException *exception) { }
    
    if ( self.writeFinishedExecuteBlock ) self.writeFinishedExecuteBlock();
}

/// 添加到内存缓存 & 写入本地
- (void)appendData:(NSData *)data {
    if ( data.length == 0 )
        return;
    [_memoryData appendData:data];
    
    // `retain self` in queue until the end of writing
    dispatch_async(serial_write_queue, ^{
        NSUInteger length = data.length;
        @try {
            [self.writer writeData:data];
        } @catch (NSException *exception) {
            dispatch_async(MCSDelegateQueue(), ^{
                [self.delegate contentReader:self anErrorOccurred:[NSError mcs_exception:exception]];
            });
        }
        
        dispatch_async(MCSDelegateQueue(), ^{
            [self.delegate contentReader:self didWriteDataWithLength:length];
        });
    });
}

- (BOOL)seekToFileOffset:(NSUInteger)offset error:(out NSError **)error {
    // 仅支持向后跳转
    if ( offset < _readLength ) {
        if ( error != NULL ) {
            *error = [NSError mcs_invalidParameterErrorWithUserInfo:@{
                NSLocalizedDescriptionKey : [NSString stringWithFormat:@"<%@>.seek 操作无法完成! 由于对读取操作的处理依赖于内存缓存, 而读取过的数据会被立即移除(内存), 所以只能向后 seek, 无法回退!", NSStringFromClass(self.class)]
            }];
        }
        return NO;
    }
    
    if ( offset > _readLength ) {
        NSUInteger availableLength = _memoryData.length;
        NSUInteger length = offset - _readLength;
        if ( length > availableLength ) {
            if ( error != NULL ) {
                *error = [NSError mcs_invalidParameterErrorWithUserInfo:@{
                    NSLocalizedDescriptionKey : [NSString stringWithFormat:@"<%@>.seek 操作无法完成! 将要跳转的偏移量不可超过当前可用长度!", NSStringFromClass(self.class)]
                }];
            }
            return NO;
        }
        NSRange range = NSMakeRange(0, length);
        [_memoryData replaceBytesInRange:range withBytes:NULL length:0];
        _readLength = offset;
    }
     
    return YES;
}

- (nullable NSData *)readDataOfLength:(NSUInteger)param {
    
    if ( _memoryData.length != 0 ) {
        NSUInteger availableLength = _memoryData.length;
        NSUInteger length = MIN(param, availableLength);
        
        NSRange range = NSMakeRange(0, length);
        NSData *data = [_memoryData subdataWithRange:range];
        [_memoryData replaceBytesInRange:range withBytes:NULL length:0];
        _readLength += length;
        return data;
    }
    
    return nil;
}

@end
