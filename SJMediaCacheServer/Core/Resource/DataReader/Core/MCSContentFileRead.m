//
//  MCSContentFileRead.m
//  Pods
//
//  Created by BlueDancer on 2020/8/24.
//

#import "MCSContentFileRead.h"
#import "NSFileHandle+MCS.h"
#import "MCSError.h"

@interface MCSContentFileRead ()
@property (nonatomic, strong) NSFileHandle *fileHandle;
@end

@implementation MCSContentFileRead

+ (nullable instancetype)readerWithPath:(NSString *)path {
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    if ( fileHandle == nil )
        return nil;
    return [MCSContentFileRead.alloc initWithFileHandle:fileHandle];
}

- (instancetype)initWithFileHandle:(NSFileHandle *)fileHandle {
    self = [super init];
    if ( self ) {
        _fileHandle = fileHandle;
    }
    return self;
}

- (BOOL)seekToFileOffset:(NSUInteger)offset error:(out NSError **)error {
    return [_fileHandle mcs_seekToFileOffset:offset error:error];
}

- (nullable NSData *)readDataOfLength:(NSUInteger)length error:(out NSError **)error {
    @try {
        return [_fileHandle readDataOfLength:length];
    } @catch (NSException *exception) {
        if ( error != NULL ) {
            *error = [NSError mcs_errorWithCode:MCSExceptionError userInfo:@{
                MCSErrorUserInfoExceptionKey : exception,
                NSLocalizedDescriptionKey : [NSString stringWithFormat:@"文件读取失败! exception: %@", exception],
            }];
        }
      return nil;
    }
}

- (void)dealloc {
    @try {
        [_fileHandle closeFile];
    } @catch (__unused NSException *exception) {
    }
}
@end
