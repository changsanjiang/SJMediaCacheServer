//
//  MCSResourceFileManager.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCSResourcePartialContent.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSResourceFileManager : NSObject
+ (NSString *)rootDirectoryPath;
+ (NSString *)databasePath;
+ (NSString *)getResourcePathWithName:(NSString *)name;
+ (NSString *)getFilePathWithName:(NSString *)name inResource:(NSString *)resourceName;

// VOD
//      返回文件名
+ (nullable NSString *)createContentFileInResource:(NSString *)resourceName atOffset:(NSUInteger)offset;

// HLS
//      返回文件名
+ (nullable NSString *)hls_createContentFileInResource:(NSString *)resourceName tsFilename:(NSString *)tsFilename tsTotalLength:(NSUInteger)length;

// HLS
//      返回文件名
+ (nullable NSString *)hls_createIndexFileInResource:(NSString *)resourceName;

// HLS
//      返回文件名
+ (nullable NSString *)hls_createAESFileInResource:(NSString *)resourceName AESFilename:(NSString *)filename;

+ (nullable NSArray<MCSResourcePartialContent *> *)getContentsInResource:(NSString *)resourceName;
@end

NS_ASSUME_NONNULL_END
