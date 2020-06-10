//
//  MCSResourceFileManager.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResourceFileManager.h"
#import <sys/xattr.h>

static NSString *VODPrefix = @"vod";
static NSString *HLSPrefix = @"hls";

@implementation MCSResourceFileManager
+ (NSString *)rootDirectoryPath {
    static NSString *rootDirectoryPath;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rootDirectoryPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:@"com.SJMediaCacheServer.cache"];
        if ( ![[NSFileManager defaultManager] fileExistsAtPath:rootDirectoryPath] ) {
            [[NSFileManager defaultManager] createDirectoryAtPath:rootDirectoryPath withIntermediateDirectories:YES attributes:nil error:NULL];
            const char *filePath = [rootDirectoryPath fileSystemRepresentation];
            const char *attrName = "com.apple.MobileBackup";
            u_int8_t attrValue = 1;
            setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
        }
    });
    return rootDirectoryPath;
}

+ (NSString *)getResourcePathWithName:(NSString *)name {
    return [[self rootDirectoryPath] stringByAppendingPathComponent:name];
}

+ (NSString *)databasePath {
    return [[self rootDirectoryPath] stringByAppendingPathComponent:@"cache.db"];
}

+ (NSString *)getFilePathWithName:(NSString *)name inResource:(NSString *)resourceName {
    return [[self getResourcePathWithName:resourceName] stringByAppendingPathComponent:name];
}
// HLS
//
+ (nullable NSString *)hls_AESKeyFilenameForURI:(NSString *)URI {
    return @"aes.key";
}

// HLS
//
+ (nullable NSString *)hls_tsFragmentsFilename {
    return @"fragments.plist";
}

// HLS
+ (nullable NSString *)hls_tsFilenameForUrl:(NSString *)url {
    NSString *component = url.lastPathComponent;
    NSRange range = [component rangeOfString:@"?"];
    if ( range.location != NSNotFound ) {
        return [component substringToIndex:range.location];
    }
    return component;
}

+ (NSString *)hls_indexFilePathInResource:(NSString *)resourceName {
    NSString *filename = @"index.m3u8";
    return [self getFilePathWithName:filename inResource:resourceName];
}

// VOD
+ (NSString *)createContentFileInResource:(NSString *)resourceName atOffset:(NSUInteger)offset {
    @autoreleasepool {
        NSString *resourcePath = [self getResourcePathWithName:resourceName];
        [self checkoutDirectoryWithPath:resourcePath];
        
        NSUInteger sequence = 0;
        while (true) {
            // VOD前缀_偏移量_序号
            NSString *filename = [NSString stringWithFormat:@"%@_%lu_%lu", VODPrefix, (unsigned long)offset, (unsigned long)sequence++];
            NSString *filepath = [self getFilePathWithName:filename inResource:resourceName];
            if ( ![NSFileManager.defaultManager fileExistsAtPath:filepath] ) {
                [NSFileManager.defaultManager createFileAtPath:filepath contents:nil attributes:nil];
                return filename;
            }
        }
    }
    return nil;
}

// HLS
+ (nullable NSString *)hls_createContentFileInResource:(NSString *)resourceName tsFilename:(NSString *)tsFilename tsTotalLength:(NSUInteger)length {
    @autoreleasepool {
        NSString *resourcePath = [self getResourcePathWithName:resourceName];
        [self checkoutDirectoryWithPath:resourcePath];
        
        NSUInteger sequence = 0;
        while (true) {
            // HLS前缀_ts文件名_ts长度_序号
            NSString *filename = [NSString stringWithFormat:@"%@_%@_%lu_%lu", HLSPrefix, tsFilename, (unsigned long)length, (unsigned long)sequence++];
            NSString *filepath = [self getFilePathWithName:filename inResource:resourceName];
            if ( ![NSFileManager.defaultManager fileExistsAtPath:filepath] ) {
                [NSFileManager.defaultManager createFileAtPath:filepath contents:nil attributes:nil];
                return filename;
            }
        }
    }
    return nil;
}

+ (nullable NSArray<MCSResourcePartialContent *> *)getContentsInResource:(NSString *)resourceName {
    @autoreleasepool {
        NSString *resourcePath = [self getResourcePathWithName:resourceName];
        NSMutableArray *m = NSMutableArray.array;
        [[NSFileManager.defaultManager contentsOfDirectoryAtPath:resourcePath error:NULL] enumerateObjectsUsingBlock:^(NSString * _Nonnull name, NSUInteger idx, BOOL * _Nonnull stop) {
            // VOD
            if      ( [name hasPrefix:VODPrefix] ) {
                NSString *path = [resourcePath stringByAppendingPathComponent:name];
                NSUInteger offset = [self offsetOfContent:name];
                NSUInteger length = [[NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL] fileSize];
                __auto_type content = [MCSResourcePartialContent.alloc initWithName:name offset:offset length:length];
                [m addObject:content];
            }
            // HLS
            else if ( [name hasPrefix:HLSPrefix] ) {
                NSString *path = [resourcePath stringByAppendingPathComponent:name];
                NSString *tsFilename = [self tsFilenameOfContent:name];
                NSUInteger tsTotalLength = [self tsTotalLengthOfContent:name];
                NSUInteger length = [[NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL] fileSize];;
                __auto_type content = [MCSResourcePartialContent.alloc initWithName:name tsFilename:tsFilename tsTotalLength:tsTotalLength length:length];
                [m addObject:content];
            }
        }];
        return m;
    }
    return nil;
}

#pragma mark -
+ (void)checkoutDirectoryWithPath:(NSString *)path {
    if ( ![NSFileManager.defaultManager fileExistsAtPath:path] ) {
        [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

// format: VOD前缀_偏移量_序号
// VOD
+ (NSUInteger)offsetOfContent:(NSString *)name {
    return [[name componentsSeparatedByString:name][1] longLongValue];
}

// format: HLS前缀_ts文件名_ts长度_序号
// HLS
+ (NSString *)tsFilenameOfContent:(NSString *)name {
    return [name componentsSeparatedByString:name][1];
}

// format: HLS前缀_ts文件名_ts长度_序号
// HLS
+ (NSUInteger)tsTotalLengthOfContent:(NSString *)name {
    return [[name componentsSeparatedByString:name][2] longLongValue];
}
@end
