//
//  MCSHLSTSFileDataReader.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/10.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResourceDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSHLSTSFileDataReader : NSObject<MCSResourceDataReader>

- (void)prepare;
@property (nonatomic, readonly) BOOL isDone;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (void)close;

@end

NS_ASSUME_NONNULL_END
