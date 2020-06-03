//
//  SJResourceDefines.h
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#ifndef SJResourceDefines_h
#define SJResourceDefines_h
#import <Foundation/Foundation.h>
@protocol SJDataReaderDelegate;

NS_ASSUME_NONNULL_BEGIN
@protocol SJDataReader <NSObject>
@property (nonatomic, weak, nullable) id<SJDataReaderDelegate> delegate;

- (void)prepare;
@property (nonatomic, readonly) UInt64 offset;
@property (nonatomic, readonly) BOOL isDone;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (void)close;
@end

@protocol SJDataReaderDelegate <NSObject>
- (void)readerPrepareDidFinish:(id<SJDataReader>)reader;
- (void)readerHasAvailableData:(id<SJDataReader>)reader;
- (void)reader:(id<SJDataReader>)reader anErrorOccurred:(NSError *)error;
@end
NS_ASSUME_NONNULL_END
#endif /* SJResourceDefines_h */
