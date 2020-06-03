//
//  SJResourceFileDataReader.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SJResourceFileDataReader : NSObject<SJDataReader>
- (instancetype)initWithPath:(NSString *)path readRange:(NSRange)range;
- (void)setDelegate:(id<SJDataReaderDelegate>)delegate delegateQueue:(dispatch_queue_t)queue;

- (void)prepare;
@property (nonatomic, readonly) UInt64 offset;
@property (nonatomic, readonly) BOOL isDone;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (void)close;
@end

NS_ASSUME_NONNULL_END
