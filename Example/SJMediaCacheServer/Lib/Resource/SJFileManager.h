//
//  SJFileManager.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SJFileManager : NSObject
+ (NSString *)resourceDirectoryPathWithURLKey:(NSString *)URLKey;
+ (NSString *)partialContentPathWithURLKey:(NSString *)URLKey atOffset:(NSUInteger)offset sequence:(NSUInteger)sequence;
+ (BOOL)checkoutDirectoryWithPath:(NSString *)path error:(NSError **)error;



+ (NSString *)partialContentFileNameWithURLKey:(NSString *)URLKey atOffset:(NSUInteger)offset;
@end

NS_ASSUME_NONNULL_END
