//
//  SJResource+SJPrivate.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/4.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResource.h"

// 私有方法, 请勿使用

NS_ASSUME_NONNULL_BEGIN
@interface SJResource (SJPrivate)
- (instancetype)initWithName:(NSString *)name;
@property (nonatomic) NSInteger id;
@property (nonatomic, strong) NSMutableArray<SJResourcePartialContent *> *contents;
- (void)setServer:(NSString * _Nullable)server contentType:(NSString * _Nullable)contentType totalLength:(NSUInteger)totalLength;
- (void)addContents:(nullable NSArray<SJResourcePartialContent *> *)contents;
@end
NS_ASSUME_NONNULL_END
