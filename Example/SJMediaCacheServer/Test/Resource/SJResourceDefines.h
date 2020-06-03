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

NS_ASSUME_NONNULL_BEGIN
@protocol SJReader <NSObject>
- (void)prepare;
@property (nonatomic, readonly) UInt64 offset;
@property (nonatomic, readonly) BOOL isDone;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (void)close;

@end
NS_ASSUME_NONNULL_END
#endif /* SJResourceDefines_h */
