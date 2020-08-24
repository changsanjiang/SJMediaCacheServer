//
//  MCSContentNetworkReadwrite.h
//  Pods
//
//  Created by BlueDancer on 2020/8/24.
//

#import "MCSResourceDefines.h"
@protocol MCSContentNetworkReadwriteDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface MCSContentNetworkReadwrite : NSObject<MCSContentReader>

+ (nullable instancetype)readerWithPath:(NSString *)path delegate:(id<MCSContentNetworkReadwriteDelegate>)delegate;

@property (nonatomic, weak, nullable) id<MCSContentNetworkReadwriteDelegate> delegate;

@property (nonatomic, copy, nullable) void(^writeFinishedExecuteBlock)(void);

- (void)appendData:(NSData *)data;

- (BOOL)seekToFileOffset:(NSUInteger)offset error:(out NSError **)error;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;

- (void)completeDownload;
@end

@protocol MCSContentNetworkReadwriteDelegate <NSObject>
- (void)contentReader:(MCSContentNetworkReadwrite *)reader anErrorOccurred:(NSError *)error;
- (void)contentReader:(MCSContentNetworkReadwrite *)reader didWriteDataWithLength:(NSUInteger)length;
@end

NS_ASSUME_NONNULL_END
