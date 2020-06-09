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
// name: 为partialContent的名字
// tsFilename: 将用作ts文件的名字
- (instancetype)initWithName:(NSString *)name tsFilename:(NSString *)tsFilename tsTotalLength:(NSUInteger)tsTotalLength length:(NSUInteger)length;
@property (nonatomic, copy, readonly) NSString *tsFilename;
@property (nonatomic, readonly) NSUInteger tsTotalLength;
@end
NS_ASSUME_NONNULL_END
