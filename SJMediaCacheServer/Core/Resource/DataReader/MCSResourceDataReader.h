//
//  MCSResourceDataReader.h
//  Pods
//
//  Created by BlueDancer on 2020/8/5.
//

#import "MCSResourceDefines.h"
@class MCSResource;

NS_ASSUME_NONNULL_BEGIN
@interface MCSResourceDataReader : NSObject<MCSResourceDataReader> {
    @protected
    __weak __kindof MCSResource *_resource;
    __weak id<MCSResourceDataReaderDelegate>_Nullable _delegate;
    NSFileHandle *_Nullable _reader;
    NSRange _range;
    NSUInteger _availableLength;
    NSUInteger _startOffsetInFile;
    NSUInteger _readLength;
    BOOL _isPrepared;
    BOOL _isCalledPrepare;
    BOOL _isClosed;
    BOOL _isSought;
}

@property (nonatomic, weak, readonly, nullable) id<MCSResourceDataReaderDelegate> delegate;
@property (nonatomic, readonly) NSRange range;
@property (nonatomic, readonly) NSUInteger availableLength;
@property (nonatomic, readonly) NSUInteger offset;
@property (nonatomic, readonly) BOOL isPrepared;
@property (nonatomic, readonly) BOOL isDone;

- (void)prepare;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (BOOL)seekToOffset:(NSUInteger)offset;
- (void)close;
@end
NS_ASSUME_NONNULL_END
