//
//  SJResourceFileDataReader.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SJResourceFileDataReader : NSObject<SJResourceDataReader>
- (instancetype)initWithRange:(NSRange)range path:(NSString *)path readRange:(NSRange)readRange;

- (void)prepare;
@property (nonatomic, readonly) BOOL isDone;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (void)close;
@end

NS_ASSUME_NONNULL_END
