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
+ (NSString *)getContentFilePathWithName:(NSString *)name inResource:(NSString *)resourceName;

// VOD
+ (nullable NSString *)createContentFileInResource:(NSString *)resourceName atOffset:(NSUInteger)offset;
// HLS
+ (nullable NSString *)createContentFileInResource:(NSString *)resourceName tsFilename:(NSString *)tsFilename tsTotalLength:(NSUInteger)length;

+ (nullable NSArray<MCSResourcePartialContent *> *)getContentsInResource:(NSString *)resourceName;
@end

NS_ASSUME_NONNULL_END
