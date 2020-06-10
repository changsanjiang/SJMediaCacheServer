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
// HLS
//
+ (nullable NSString *)hls_AESKeyFilenameForURI:(NSString *)URI;

// HLS
//
+ (nullable NSString *)hls_tsFragmentsFilename;

// HLS
//
+ (nullable NSString *)hls_tsNameForUrl:(NSString *)url;

// HLS
//
+ (nullable NSString *)hls_indexFilePathInResource:(NSString *)resourceName;


// VOD
//      注意: 返回文件名
+ (nullable NSString *)createContentFileInResource:(NSString *)resourceName atOffset:(NSUInteger)offset;

// HLS
//      注意: 返回文件名
+ (nullable NSString *)hls_createContentFileInResource:(NSString *)resourceName tsName:(NSString *)tsName tsContentType:(NSString *)tsContentType tsTotalLength:(NSUInteger)length;

+ (nullable NSArray<MCSResourcePartialContent *> *)getContentsInResource:(NSString *)resourceName;
@end

NS_ASSUME_NONNULL_END
