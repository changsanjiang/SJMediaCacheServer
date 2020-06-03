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
@protocol SJReaderDelegate;

NS_ASSUME_NONNULL_BEGIN
@protocol SJReader <NSObject>
@property (nonatomic, weak, nullable) id<SJReaderDelegate> delegate;

- (void)prepare;
@property (nonatomic, readonly) UInt64 offset;
@property (nonatomic, readonly) BOOL isDone;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (void)close;
@end

@protocol SJReaderDelegate <NSObject>
- (void)readerPrepareDidFinish:(id<SJReader>)reader;
- (void)readerHasAvailableData:(id<SJReader>)reader;
- (void)reader:(id<SJReader>)reader anErrorOccurred:(NSError *)error;
@end
NS_ASSUME_NONNULL_END
#endif /* SJResourceDefines_h */
