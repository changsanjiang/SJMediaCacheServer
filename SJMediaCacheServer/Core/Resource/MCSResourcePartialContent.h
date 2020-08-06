//
//  MCSResourcePartialContent.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCSDefines.h"

NS_ASSUME_NONNULL_BEGIN
@interface MCSResourcePartialContent : NSObject
@property (nonatomic, copy, readonly) NSString *filename;
@property (nonatomic, readonly) NSUInteger length;
@property (nonatomic, readonly) MCSDataType type;
- (void)didWriteDataWithLength:(NSUInteger)length;
@end

#warning next ... 子类化
@interface MCSResourcePartialContent (VOD)
- (instancetype)initWithFilename:(NSString *)filename offset:(NSUInteger)offset  __deprecated;
- (instancetype)initWithFilename:(NSString *)filename offset:(NSUInteger)offset length:(NSUInteger)length  __deprecated;
@property (nonatomic, readonly) NSUInteger offset;
@end

#warning next ... 子类化
@interface MCSResourcePartialContent (HLS_TS)
- (instancetype)initWithFilename:(NSString *)filename tsName:(NSString *)tsName tsTotalLength:(NSUInteger)tsTotalLength length:(NSUInteger)length __deprecated;
@property (nonatomic, copy, readonly) NSString *tsName;
@property (nonatomic, readonly) NSUInteger tsTotalLength;
@end


@interface MCSHLSIndexPartialContent : MCSResourcePartialContent
- (instancetype)initWithFilename:(NSString *)filename totalLength:(NSUInteger)totalLength length:(NSUInteger)length;
@property (nonatomic, readonly) NSUInteger totalLength;
@end

@interface MCSHLSAESKeyPartialContent : MCSResourcePartialContent
- (instancetype)initWithFilename:(NSString *)filename AESKeyName:(NSString *)AESKeyName totalLength:(NSUInteger)totalLength length:(NSUInteger)length;
@property (nonatomic, copy, readonly) NSString *AESKeyName;
@property (nonatomic, readonly) NSUInteger totalLength;
@end

@interface MCSHLSTsPartialContent : MCSResourcePartialContent
- (instancetype)initWithFilename:(NSString *)filename TsName:(NSString *)TsName totalLength:(NSUInteger)totalLength length:(NSUInteger)length;
@property (nonatomic, copy, readonly) NSString *TsName;
@property (nonatomic, readonly) NSUInteger totalLength;
@end
NS_ASSUME_NONNULL_END
