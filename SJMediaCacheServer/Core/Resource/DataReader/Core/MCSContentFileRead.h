//
//  MCSContentFileRead.h
//  Pods
//
//  Created by BlueDancer on 2020/8/24.
//

#import "MCSResourceDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSContentFileRead : NSObject<MCSContentReader>

+ (nullable instancetype)readerWithPath:(NSString *)path;

- (BOOL)seekToFileOffset:(NSUInteger)offset error:(out NSError **)error;
- (nullable NSData *)readDataOfLength:(NSUInteger)length error:(out NSError **)error;

@end

NS_ASSUME_NONNULL_END
