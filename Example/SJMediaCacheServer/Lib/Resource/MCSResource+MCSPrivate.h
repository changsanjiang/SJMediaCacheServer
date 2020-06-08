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
@protocol MCSReadWrite <NSObject>
@property (nonatomic, readonly) NSInteger readWriteCount;

- (void)readWrite_retain;
- (void)readWrite_release;
@end

@interface MCSResource (MCSPrivate)<MCSReadWrite>
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

@property (nonatomic, readonly) NSInteger readWriteCount;
- (void)readWrite_retain;
- (void)readWrite_release;

@property (nonatomic) NSInteger numberOfCumulativeUsage; ///< 累计被使用次数
@property (nonatomic) NSTimeInterval updatedTime;        ///< 最后一次更新时的时间
@property (nonatomic) NSTimeInterval createdTime;        ///< 创建时间
@end

@interface MCSResourcePartialContent (MCSPrivate)<MCSReadWrite>
@property (nonatomic, weak, nullable) id<MCSResourcePartialContentDelegate> delegate;

@property (nonatomic, readonly) NSInteger readWriteCount;
- (void)readWrite_retain;
- (void)readWrite_release;
@end

@protocol MCSResourcePartialContentDelegate <NSObject>
- (void)readWriteCountDidChangeForPartialContent:(MCSResourcePartialContent *)content;
@end
NS_ASSUME_NONNULL_END
