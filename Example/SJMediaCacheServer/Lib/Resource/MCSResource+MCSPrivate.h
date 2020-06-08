//
//  MCSResource+MCSPrivate.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/4.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResource.h"
#import "MCSResourcePartialContent.h"
@protocol MCSResourcePartialContentDelegate;

// 私有方法, 请勿使用

NS_ASSUME_NONNULL_BEGIN
@interface MCSResource (MCSPrivate)
- (instancetype)initWithName:(NSString *)name;
@property (nonatomic) NSInteger id;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, strong, readonly) NSMutableArray<MCSResourcePartialContent *> *contents;
- (void)setServer:(NSString * _Nullable)server contentType:(NSString * _Nullable)contentType totalLength:(NSUInteger)totalLength;
- (void)addContents:(nullable NSArray<MCSResourcePartialContent *> *)contents;
- (NSString *)filePathOfContent:(MCSResourcePartialContent *)content;
- (MCSResourcePartialContent *)createContentWithOffset:(NSUInteger)offset;
@property (nonatomic, copy, readonly, nullable) NSString *contentType;
@property (nonatomic, copy, readonly, nullable) NSString *server;
@property (nonatomic, readonly) NSUInteger totalLength;
@end

@interface MCSResourcePartialContent (MCSPrivate)
@property (nonatomic, weak, nullable) id<MCSResourcePartialContentDelegate> delegate;
@property (readonly) NSInteger readWriteCount;

- (void)readWrite_retain;
- (void)readWrite_release;
@end

@protocol MCSResourcePartialContentDelegate <NSObject>
- (void)readWriteCountDidChangeForPartialContent:(MCSResourcePartialContent *)content;
@end
NS_ASSUME_NONNULL_END
