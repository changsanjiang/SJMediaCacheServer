//
//  SJResource+SJPrivate.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/4.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResource.h"
#import "SJResourcePartialContent.h"
@protocol SJResourcePartialContentDelegate;

// 私有方法, 请勿使用

NS_ASSUME_NONNULL_BEGIN
@interface SJResource (SJPrivate)
- (instancetype)initWithName:(NSString *)name;
@property (nonatomic) NSInteger id;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, strong, readonly) NSMutableArray<SJResourcePartialContent *> *contents;
- (void)setServer:(NSString * _Nullable)server contentType:(NSString * _Nullable)contentType totalLength:(NSUInteger)totalLength;
- (void)addContents:(nullable NSArray<SJResourcePartialContent *> *)contents;
- (NSString *)filePathOfContent:(SJResourcePartialContent *)content;
- (SJResourcePartialContent *)createContentWithOffset:(NSUInteger)offset;
@property (nonatomic, copy, readonly, nullable) NSString *contentType;
@property (nonatomic, copy, readonly, nullable) NSString *server;
@property (nonatomic, readonly) NSUInteger totalLength;
@end

@interface SJResourcePartialContent (SJPrivate)
@property (nonatomic, weak, nullable) id<SJResourcePartialContentDelegate> delegate;
@property (readonly) NSInteger referenceCount;

- (void)reference_retain;
- (void)reference_release;
@end

@protocol SJResourcePartialContentDelegate <NSObject>
- (void)partialContent:(SJResourcePartialContent *)content referenceCountDidChange:(NSUInteger)referenceCount;
@end
NS_ASSUME_NONNULL_END
