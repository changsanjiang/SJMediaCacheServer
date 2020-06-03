//
//  SJResourceFileManager.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceFileManager.h"
#import <sys/xattr.h>

static NSString *rootDirectoryPath;

@implementation SJResourceFileManager

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rootDirectoryPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:@"com.SJMediaCacheServer.cache"];
        if ( ![[NSFileManager defaultManager] fileExistsAtPath:rootDirectoryPath] ) {
            [[NSFileManager defaultManager] createDirectoryAtPath:rootDirectoryPath withIntermediateDirectories:YES attributes:nil error:nil];
            const char *filePath = [rootDirectoryPath fileSystemRepresentation];
            const char *attrName = "com.apple.MobileBackup";
            u_int8_t attrValue = 1;
            setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
        }
    });
}

+ (NSString *)resourceDirectoryPathWithURLKey:(NSString *)URLKey {
    return [rootDirectoryPath stringByAppendingPathComponent:URLKey];
}

+ (NSString *)partialContentPathWithURLKey:(NSString *)URLKey atOffset:(NSUInteger)offset sequence:(NSUInteger)sequence {
    return [[self resourceDirectoryPathWithURLKey:URLKey] stringByAppendingPathComponent:[NSString stringWithFormat:@"%lu_%lu", (unsigned long)offset, (unsigned long)sequence]];
}

+ (BOOL)checkoutDirectoryWithPath:(NSString *)path error:(NSError **)error {
    if ( ![NSFileManager.defaultManager fileExistsAtPath:path] ) {
        if ( ![NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error] ) {
            return YES;
        }
    }
    return NO;
}

+ (NSString *)checkoutPartialContentFileWithURLKey:(NSString *)URLKey atOffset:(NSUInteger)offset {
    @autoreleasepool {
        NSUInteger sequence = 0;
        while (1) {
            NSString *filepath = [self partialContentPathWithURLKey:URLKey atOffset:offset sequence:sequence++];
            if ( ![NSFileManager.defaultManager fileExistsAtPath:filepath] ) {
                [NSFileManager.defaultManager createFileAtPath:filepath contents:nil attributes:nil];
                return filepath;
            }
        }
    }
    return nil;
}


#pragma mark -

+ (NSString *)getContentFilePathWithName:(NSString *)name inResource:(NSString *)directory {
    return [directory stringByAppendingPathComponent:name];
}

+ (NSString *)createContentFileWithResource:(NSString *)directory atOffset:(NSUInteger)offset {
    @autoreleasepool {
        NSUInteger sequence = 0;
        while (1) {
            NSString *filename = [NSString stringWithFormat:@"%lu_%lu", (unsigned long)offset, (unsigned long)sequence++];
            NSString *filepath = [directory stringByAppendingPathComponent:filename];
            if ( ![NSFileManager.defaultManager fileExistsAtPath:filepath] ) {
                [NSFileManager.defaultManager createFileAtPath:filepath contents:nil attributes:nil];
                return filepath;
            }
        }
    }
    return nil;
}
@end
