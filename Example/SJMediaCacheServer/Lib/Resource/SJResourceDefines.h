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
@protocol SJResourceDataReaderDelegate;

NS_ASSUME_NONNULL_BEGIN
@protocol SJResourceDataReader <NSObject>

@property (nonatomic, weak, nullable) id<SJResourceDataReaderDelegate> delegate;

- (void)prepare;
@property (nonatomic, readonly) BOOL isDone;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (void)close;
@end

@protocol SJResourceDataReaderDelegate <NSObject>
- (void)readerPrepareDidFinish:(id<SJResourceDataReader>)reader;
- (void)readerHasAvailableData:(id<SJResourceDataReader>)reader;
- (void)reader:(id<SJResourceDataReader>)reader anErrorOccurred:(NSError *)error;
@end
NS_ASSUME_NONNULL_END
#endif /* SJResourceDefines_h */
