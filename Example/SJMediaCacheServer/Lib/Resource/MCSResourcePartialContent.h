//
//  MCSResourcePartialContent.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface MCSResourcePartialContent : NSObject
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic) NSUInteger length;
@end

@interface MCSResourcePartialContent (VOD)
- (instancetype)initWithName:(NSString *)name offset:(NSUInteger)offset;
- (instancetype)initWithName:(NSString *)name offset:(NSUInteger)offset length:(NSUInteger)length;
@property (nonatomic, readonly) NSUInteger offset;
@end

@interface MCSResourcePartialContent (HLS)
- (instancetype)initWithName:(NSString *)name;
@end
NS_ASSUME_NONNULL_END
