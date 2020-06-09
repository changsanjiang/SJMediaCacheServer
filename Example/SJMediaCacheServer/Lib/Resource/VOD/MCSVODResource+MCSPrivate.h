//
//  MCSResource+MCSPrivate.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/4.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSVODResource.h"
#import "MCSVODResourcePartialContent.h"
#import "MCSResourceSubclass.h"
#import "MCSResourceDefines.h"
@protocol MCSVODResourcePartialContentDelegate;

// 私有方法, 请勿使用

NS_ASSUME_NONNULL_BEGIN
@interface MCSVODResource (MCSPrivate)<MCSReadWrite>
@property (nonatomic) NSInteger id;
@property (nonatomic, strong, readonly) NSMutableArray<MCSVODResourcePartialContent *> *contents;
- (void)setServer:(NSString * _Nullable)server contentType:(NSString * _Nullable)contentType totalLength:(NSUInteger)totalLength;
- (void)addContents:(nullable NSArray<MCSVODResourcePartialContent *> *)contents;
- (NSString *)filePathOfContent:(MCSVODResourcePartialContent *)content;
- (MCSVODResourcePartialContent *)createContentWithOffset:(NSUInteger)offset;
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

@interface MCSVODResourcePartialContent (MCSPrivate)<MCSReadWrite>
@property (nonatomic, weak, nullable) id<MCSVODResourcePartialContentDelegate> delegate;

@property (nonatomic, readonly) NSInteger readWriteCount;
- (void)readWrite_retain;
- (void)readWrite_release;
@end

@protocol MCSVODResourcePartialContentDelegate <NSObject>
- (void)readWriteCountDidChangeForPartialContent:(MCSVODResourcePartialContent *)content;
- (void)contentLengthDidChangeForPartialContent:(MCSVODResourcePartialContent *)content;
@end
NS_ASSUME_NONNULL_END
