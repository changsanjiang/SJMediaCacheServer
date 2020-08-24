//
//  MCSContentNetworkReadwrite.h
//  Pods
//
//  Created by BlueDancer on 2020/8/24.
//

#import "MCSResourceDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSContentNetworkReadwrite : NSObject<MCSContentReader>

+ (nullable instancetype)readerWithPath:(NSString *)path;

@property (nonatomic, copy, nullable) void(^onErrorExecuteBlock)(NSError *error);
@property (nonatomic, copy, nullable) void(^didWriteDataExecuteBlock)(NSUInteger length);
@property (nonatomic, copy, nullable) void(^writeFinishedExecuteBlock)(void);

- (void)appendData:(NSData *)data;

- (BOOL)seekToFileOffset:(NSUInteger)offset error:(out NSError **)error;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;

- (void)completeDownload;
@end
NS_ASSUME_NONNULL_END
