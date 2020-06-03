//
//  SJResourceReader.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJMediaCacheServerDefines.h"
#import "SJResourcePartialContent.h"

NS_ASSUME_NONNULL_BEGIN

@interface SJResourceReader : NSObject<SJResourceReader>
- (instancetype)initWithPartialContents:(NSArray<SJResourcePartialContent *> *)contents;
@property (nonatomic, copy, readonly) NSArray<SJResourcePartialContent *> *contents;
@property (nonatomic, weak, nullable) id<SJResourceReaderDelegate> delegate;

- (void)prepare;
@property (nonatomic, readonly) UInt64 contentLength;
@property (nonatomic, readonly) UInt64 offset;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
@property (nonatomic, readonly) BOOL isReadingEndOfData;
- (void)close;
@end

NS_ASSUME_NONNULL_END
