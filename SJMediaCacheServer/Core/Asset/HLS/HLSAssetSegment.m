//
//  HLSAssetSegment.m
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/11/25.
//

#import "HLSAssetSegment.h"
 
@implementation HLSAssetSegment
- (instancetype)initWithMimeType:(nullable NSString *)mimeType filePath:(NSString *)filePath totalLength:(UInt64)totalLength {
    return [self initWithMimeType:mimeType filePath:filePath totalLength:totalLength length:0 byteRange:(NSRange){ 0, totalLength }];
}
- (instancetype)initWithMimeType:(nullable NSString *)mimeType filePath:(NSString *)filePath totalLength:(UInt64)totalLength length:(UInt64)length {
    return [self initWithMimeType:mimeType filePath:filePath totalLength:totalLength length:length byteRange:(NSRange){ 0, totalLength }];
}
- (instancetype)initWithMimeType:(nullable NSString *)mimeType filePath:(NSString *)filePath totalLength:(UInt64)totalLength byteRange:(NSRange)byteRange {
    return [self initWithMimeType:mimeType filePath:filePath totalLength:totalLength length:0 byteRange:byteRange];
}
- (instancetype)initWithMimeType:(nullable NSString *)mimeType filePath:(NSString *)filePath totalLength:(UInt64)totalLength length:(UInt64)length byteRange:(NSRange)byteRange {
    self = [super initWithMimeType:mimeType filePath:filePath position:byteRange.location length:length];
    _byteRange = byteRange;
    _totalLength = totalLength;
    return self;
}

- (NSString *)description {
    @synchronized (self) {
        return [NSString stringWithFormat:@"%@: <%p> { totalLength: %llu, byteRange=%@, position: %llu, length: %llu, readwriteCount: %ld, filePath: %@ };\n", NSStringFromClass(self.class), self, self.totalLength, NSStringFromRange(self.byteRange), self.position, self.length, (long)self.readwriteCount, self.filePath];
    }
}

@end
