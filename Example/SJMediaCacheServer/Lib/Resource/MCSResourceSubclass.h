//
//  MCSResource+Subclass.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResource.h"
#import "MCSResourceUsageLog.h"
#import "MCSResourceDefines.h"
#import "MCSResourcePartialContent.h"
@protocol MCSResourcePartialContentDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface MCSResource (Private)<NSLocking>
@property (nonatomic) NSInteger id;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) MCSResourceUsageLog *log;

@property (nonatomic, readonly) NSInteger readWriteCount;
- (void)readWrite_retain;
- (void)readWrite_release;
@end


@interface MCSResourcePartialContent (MCSPrivate)<MCSReadWrite>
@property (nonatomic, weak, nullable) id<MCSResourcePartialContentDelegate> delegate;

@property (nonatomic, readonly) NSInteger readWriteCount;
- (void)readWrite_retain;
- (void)readWrite_release;
@end

@protocol MCSResourcePartialContentDelegate <NSObject>
- (void)readWriteCountDidChangeForPartialContent:(MCSResourcePartialContent *)content;
- (void)contentLengthDidChangeForPartialContent:(MCSResourcePartialContent *)content;
@end
NS_ASSUME_NONNULL_END
