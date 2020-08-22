//
//  MCSResourceFileDataReader.h
//  Pods
//
//  Created by BlueDancer on 2020/8/5.
//

#import "MCSResourceDataReader.h"
@class MCSResourcePartialContent;

NS_ASSUME_NONNULL_BEGIN

@interface MCSResourceFileDataReader : MCSResourceDataReader

- (instancetype)initWithResource:(MCSResource *)resource inRange:(NSRange)range partialContent:(MCSResourcePartialContent *)content startOffsetInFile:(NSUInteger)startOffsetInFile  delegate:(id<MCSResourceDataReaderDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
