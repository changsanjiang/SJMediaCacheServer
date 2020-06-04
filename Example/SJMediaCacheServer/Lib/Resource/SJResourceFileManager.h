//
//  SJResourceFileManager.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SJResourcePartialContent.h"

NS_ASSUME_NONNULL_BEGIN

@interface SJResourceFileManager : NSObject
+ (NSString *)rootDirectoryPath;
+ (NSString *)databasePath;
+ (NSString *)getResourcePathWithName:(NSString *)name;
+ (NSString *)getContentFilePathWithName:(NSString *)name inResource:(NSString *)resourceName;
+ (NSString *)createContentFileInResource:(NSString *)resourceName atOffset:(NSUInteger)offset;
+ (nullable NSArray<SJResourcePartialContent *> *)getContentsInResource:(NSString *)resourceName;
@end

NS_ASSUME_NONNULL_END
