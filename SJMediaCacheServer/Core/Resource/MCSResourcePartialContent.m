//
//  MCSResourcePartialContent.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResourcePartialContent.h"
#import "MCSResourceSubclass.h"

@interface MCSResourcePartialContent ()
@property (nonatomic) NSInteger readWriteCount;

- (void)readWrite_retain;
- (void)readWrite_release;
@end

@implementation MCSResourcePartialContent
- (instancetype)initWithType:(MCSDataType)type filename:(NSString *)filename length:(NSUInteger)length {
    self = [super init];
    if ( self ) {
        _type = type;
        _filename = filename.copy;
        _length = length;
    }
    return self;
}
    
- (void)readWrite_retain {
    self.readWriteCount += 1;
}

- (void)readWrite_release {
    self.readWriteCount -= 1;
}

- (void)didWriteDataWithLength:(NSUInteger)length {
    _length += length;
}

@end

@implementation MCSVODPartialContent
- (instancetype)initWithFilename:(NSString *)filename offset:(NSUInteger)offset length:(NSUInteger)length {
    self = [super initWithType:MCSDataTypeVOD filename:filename length:length];
    if ( self ) {
        _offset = offset;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%s: <%p> { name: %@, offset: %lu, length: %lu, readWriteCount: %lu };", NSStringFromClass(self.class).UTF8String, self, self.filename, (unsigned long)_offset, (unsigned long)self.length, (unsigned long)self.readWriteCount];
}
@end


@implementation MCSHLSPartialContent
+ (instancetype)AESKeyPartialContentWithFilename:(NSString *)filename name:(NSString *)name totalLength:(NSUInteger)totalLength length:(NSUInteger)length {
    return [MCSHLSPartialContent.alloc initWithType:MCSDataTypeHLSAESKey filename:filename name:name totalLength:totalLength length:length];
}

+ (instancetype)TsPartialContentWithFilename:(NSString *)filename name:(NSString *)name totalLength:(NSUInteger)totalLength length:(NSUInteger)length {
    return [MCSHLSPartialContent.alloc initWithType:MCSDataTypeHLSTs filename:filename name:name totalLength:totalLength length:length];
}

- (instancetype)initWithType:(MCSDataType)type filename:(NSString *)filename name:(NSString *)name totalLength:(NSUInteger)totalLength length:(NSUInteger)length {
    self = [super initWithType:type filename:filename length:length];
    if ( self ) {
        _totalLength = totalLength;;
        _name = name;
    }
    return self;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"%s: <%p> { name: %@, totalLength: %lu, length: %lu, readWriteCount: %lu  };", NSStringFromClass(self.class).UTF8String, self, self.filename, (unsigned long)_totalLength, (unsigned long)self.length, self.readWriteCount];
}
@end
