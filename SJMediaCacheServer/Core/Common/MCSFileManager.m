//
//  MCSFileManager.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSFileManager.h"
#import <sys/xattr.h>

MCSFileExtension const MCSHLSIndexFileExtension = @".m3u8";
MCSFileExtension const MCSHLSTsFileExtension = @".ts";
MCSFileExtension const MCSHLSAESKeyFileExtension = @".key";

@implementation MCSFileManager
static NSString *VODPrefix = @"vod";
static NSString *HLSPrefix = @"hls";

+ (void)lockWithBlock:(void (^)(void))block {
    dispatch_barrier_sync(dispatch_get_global_queue(0, 0), block);
}

+ (NSString *)rootDirectoryPath {
    static NSString *rootDirectoryPath;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        rootDirectoryPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:@"com.SJMediaCacheServer.cache"];
        if ( ![NSFileManager.defaultManager fileExistsAtPath:rootDirectoryPath] ) {
            [NSFileManager.defaultManager createDirectoryAtPath:rootDirectoryPath withIntermediateDirectories:YES attributes:nil error:NULL];
            const char *filePath = [rootDirectoryPath fileSystemRepresentation];
            const char *attrName = "com.apple.MobileBackup";
            u_int8_t attrValue = 1;
            setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
        }
    });
    return rootDirectoryPath;
}

+ (NSString *)databasePath {
    return [[self rootDirectoryPath] stringByAppendingPathComponent:@"cache.db"];
}

+ (NSString *)getResourcePathWithName:(NSString *)name {
    return [[self rootDirectoryPath] stringByAppendingPathComponent:name];
}

+ (NSString *)getFilePathWithName:(NSString *)name inResource:(NSString *)resourceName {
    return [[self getResourcePathWithName:resourceName] stringByAppendingPathComponent:name];
}
   
+ (nullable NSArray<MCSResourcePartialContent *> *)getContentsInResource:(NSString *)resourceName {
    NSString *resourcePath = [self getResourcePathWithName:resourceName];
    NSMutableArray *m = NSMutableArray.array;
    [[NSFileManager.defaultManager contentsOfDirectoryAtPath:resourcePath error:NULL] enumerateObjectsUsingBlock:^(NSString * _Nonnull filename, NSUInteger idx, BOOL * _Nonnull stop) {
        // VOD
        if      ( [filename hasPrefix:VODPrefix] ) {
            NSString *path = [resourcePath stringByAppendingPathComponent:filename];
            NSUInteger offset = [self vod_offsetOfContent:filename];
            NSUInteger length = [self fileSizeAtPath:path];
            __auto_type content = [MCSVODPartialContent.alloc initWithFilename:filename offset:offset length:length];
            [m addObject:content];
        }
        // HLS
        else if ( [filename hasPrefix:HLSPrefix] ) {
            NSString *path = [resourcePath stringByAppendingPathComponent:filename];
            NSString *name = [self hls_nameOfContent:filename];
            NSUInteger totalLength = [self hls_totalLengthOfContent:filename];
            NSUInteger length = [self fileSizeAtPath:path];
            
            MCSHLSPartialContent *content = nil;
            if ( [name containsString:MCSHLSTsFileExtension] ) {
                content = [MCSHLSPartialContent TsPartialContentWithFilename:filename name:name totalLength:totalLength length:length];
            }
            else if ( [name containsString:MCSHLSAESKeyFileExtension] ) {
                content = [MCSHLSPartialContent AESKeyPartialContentWithFilename:filename name:name totalLength:totalLength length:length];
            }
            [m addObject:content];
        }
    }];
    return m;
}


// format: HLS前缀_长度_序号_name
+ (nullable NSString *)hls_nameOfContent:(NSString *)contentFilename {
    return [contentFilename componentsSeparatedByString:@"_"].lastObject;
}

// format: HLS前缀_长度_序号_name
+ (NSUInteger)hls_totalLengthOfContent:(NSString *)contentFilename {
    return (NSUInteger)[[contentFilename componentsSeparatedByString:@"_"][1] longLongValue];
}

// format: VOD前缀_偏移量_序号.扩展名
+ (NSUInteger)vod_offsetOfContent:(NSString *)contentFilename {
    return (NSUInteger)[[contentFilename componentsSeparatedByString:@"_"][1] longLongValue];
}
@end


#pragma mark -


@implementation MCSFileManager (VOD)

// VOD
//      注意: 返回文件名
+ (nullable NSString *)vod_createContentFileInResource:(NSString *)resourceName atOffset:(NSUInteger)offset pathExtension:(nullable NSString *)pathExtension {
    __block NSString *filename = nil;
    dispatch_barrier_sync(dispatch_get_global_queue(0, 0), ^{
        NSUInteger sequence = 0;
        while (true) {
            // VOD前缀_偏移量_序号.扩展名
            NSString *fname = [NSString stringWithFormat:@"%@_%lu_%lu", VODPrefix, (unsigned long)offset, (unsigned long)sequence++];
            if ( pathExtension.length != 0 ) fname = [fname stringByAppendingPathExtension:pathExtension];
            NSString *filePath = [self getFilePathWithName:fname inResource:resourceName];
            if ( ![NSFileManager.defaultManager fileExistsAtPath:filePath] ) {
                [NSFileManager.defaultManager createFileAtPath:filePath contents:nil attributes:nil];
                filename = fname;
                return;
            }
        }
    });
    return filename;
}

@end

#pragma mark -

@implementation MCSFileManager (HLS)

+ (NSString *)hls_indexFilePathInResource:(NSString *)resourceName {
    NSString *filename = @"index.m3u8";
    return [self getFilePathWithName:filename inResource:resourceName];
}

//      注意: 返回文件名
+ (NSString *)hls_createAESKeyFileInResource:(NSString *)resourceName AESKeyName:(NSString *)AESKeyName totalLength:(NSUInteger)totalLength {
    // format: HLS前缀_长度_序号_name
    //
    __block NSString *filename = nil;
    [self lockWithBlock:^{
        NSUInteger sequence = 0;
        do {
            NSString *fname = [NSString stringWithFormat:@"%@_%lu_%lu_%@", HLSPrefix, (unsigned long)totalLength, (unsigned long)sequence++, AESKeyName];
            NSString *filePath = [self getFilePathWithName:fname inResource:resourceName];
            if ( ![NSFileManager.defaultManager fileExistsAtPath:filePath] ) {
                [NSFileManager.defaultManager createFileAtPath:filePath contents:nil attributes:nil];
                filename = fname;
                return;
            }
        } while (true);
    }];
    return filename;
}

//      注意: 返回文件名
+ (NSString *)hls_createTsFileInResource:(NSString *)resourceName tsName:(NSString *)tsName tsTotalLength:(NSUInteger)length {
    __block NSString *filename = nil;
    [self lockWithBlock:^{
        NSUInteger sequence = 0;
        while (true) {
            // format: HLS前缀_长度_序号_name
            //
            NSString *fname = [NSString stringWithFormat:@"%@_%lu_%lu_%@", HLSPrefix, (unsigned long)length, (unsigned long)sequence++, tsName];
            NSString *filePath = [self getFilePathWithName:fname inResource:resourceName];
            if ( ![NSFileManager.defaultManager fileExistsAtPath:filePath] ) {
                [NSFileManager.defaultManager createFileAtPath:filePath contents:nil attributes:nil];
                filename = fname;
                return;
            }
        }
    }];
    return filename;
}

@end

#pragma mark -


@implementation MCSFileManager (FileSize)
+ (NSUInteger)rootDirectorySize {
    return [self directorySizeAtPath:[self rootDirectoryPath]];
}

+ (NSUInteger)systemFreeSize {
    return [[NSFileManager.defaultManager attributesOfFileSystemForPath:NSHomeDirectory() error:NULL][NSFileSystemFreeSize] unsignedLongValue];
}
 
+ (NSUInteger)directorySizeAtPath:(NSString *)path {
    NSUInteger size = 0;
    for ( NSString *subpath in [NSFileManager.defaultManager subpathsAtPath:path] )
        size += [self fileSizeAtPath:[path stringByAppendingPathComponent:subpath]];
    return size;
}

+ (NSUInteger)fileSizeAtPath:(NSString *)path {
    return (NSUInteger)[NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL].fileSize;
}
@end

@implementation MCSFileManager (FileManager)
+ (BOOL)removeItemAtPath:(NSString *)path error:(NSError *__autoreleasing  _Nullable *)error {
    return [NSFileManager.defaultManager removeItemAtPath:path error:error];
}

+ (BOOL)fileExistsAtPath:(NSString *)path {
    return [NSFileManager.defaultManager fileExistsAtPath:path];
}

+ (BOOL)checkoutResourceWithName:(NSString *)name error:(NSError **)error {
    NSString *path = [MCSFileManager getResourcePathWithName:name];
    if ( ![MCSFileManager fileExistsAtPath:path] ) {
        return [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error];
    }
    return YES;
}

+ (BOOL)removeResourceWithName:(NSString *)name error:(NSError **)error {
    NSString *path = [MCSFileManager getResourcePathWithName:name];
    return [NSFileManager.defaultManager removeItemAtPath:path error:NULL];
}

+ (BOOL)removeContentWithName:(NSString *)name inResource:(NSString *)resourceName error:(NSError **)error {
    NSString *path = [MCSFileManager getFilePathWithName:name inResource:resourceName];
    return [self removeItemAtPath:path error:error];
}
@end
