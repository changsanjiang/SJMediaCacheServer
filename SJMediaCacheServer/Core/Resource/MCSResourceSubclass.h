//
//  MCSResource+Subclass.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResource.h"
#import "MCSResourceUsageLog.h"
#import "MCSResourceDefines.h"
#import "MCSResourcePartialContent.h"

NS_ASSUME_NONNULL_BEGIN
@interface MCSResourcePartialContent (MCSPrivate)<MCSReadWrite>
@property (nonatomic, readonly) NSInteger readwriteCount;
- (void)readwriteRetain;
- (void)readwriteRelease;
- (void)didWriteDataWithLength:(NSUInteger)length;
@end

@interface MCSResource (Private)<MCSReadWrite>
@property (nonatomic, strong, readonly) dispatch_queue_t queue;
@property (nonatomic) NSInteger id;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) MCSResourceUsageLog *log;

#pragma mark -
@property (nonatomic, readonly) NSInteger readwriteCount;
- (void)readwriteRetain;
- (void)readwriteRelease;

#pragma mark -

- (void)_addContents:(nullable NSArray<MCSResourcePartialContent *> *)contents;
- (void)_addContent:(MCSResourcePartialContent *)content;
- (void)_removeContent:(MCSResourcePartialContent *)content;
- (void)_removeContents:(NSArray<MCSResourcePartialContent *> *)contents;
- (void)_contentsDidChange:(NSArray<MCSResourcePartialContent *> *)contents;
- (void)_didWriteDataForContent:(MCSResourcePartialContent *)content length:(NSUInteger)length;
@end
NS_ASSUME_NONNULL_END
