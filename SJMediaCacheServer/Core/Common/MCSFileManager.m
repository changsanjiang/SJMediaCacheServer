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
static dispatch_semaphore_t _semaphore;
static NSString *VODPrefix = @"vod";
static NSString *HLSPrefix = @"hls";

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _semaphore = dispatch_semaphore_create(1);
    });
}

+ (void)lock {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
}

+ (void)unlock {
    dispatch_semaphore_signal(_semaphore);
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

+ (NSString *)getResourcePathWithName:(NSString *)name {
    return [[self rootDirectoryPath] stringByAppendingPathComponent:name];
}

+ (NSString *)databasePath {
    return [[self rootDirectoryPath] stringByAppendingPathComponent:@"cache.db"];
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
            NSUInteger offset = [self offsetOfContent:filename];
            NSUInteger length = (NSUInteger)[[NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL] fileSize];
            __auto_type content = [MCSResourcePartialContent.alloc initWithFilename:filename offset:offset length:length];
            [m addObject:content];
        }
        // HLS
        else if ( [filename hasPrefix:HLSPrefix] ) {
            NSString *path = [resourcePath stringByAppendingPathComponent:filename];
            if ( [filename containsString:MCSHLSTsFileExtension] ) {
                NSString *tsName = [self tsNameOfContent:filename];
                NSUInteger tsTotalLength = [self tsTotalLengthOfContent:filename];
                NSUInteger length = (NSUInteger)[[NSFileManager.defaultManager attributesOfItemAtPath:path error:NULL] fileSize];;
                __auto_type content = [MCSResourcePartialContent.alloc initWithFilename:filename tsName:tsName  tsTotalLength:tsTotalLength length:length];
                [m addObject:content];
            }
            else if ( [filename containsString:MCSHLSAESKeyFileExtension] ) {
#warning next ...
            }
        }
    }];
    return m;
}

#pragma mark -
+ (void)checkoutDirectoryWithPath:(NSString *)path {
    if ( ![NSFileManager.defaultManager fileExistsAtPath:path] ) {
        [NSFileManager.defaultManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

// format: // VOD前缀_偏移量_序号.扩展名
// VOD
+ (NSUInteger)offsetOfContent:(NSString *)name {
    return (NSUInteger)[[name componentsSeparatedByString:@"_"][1] longLongValue];
}

// format: HLS前缀_ts长度_序号_tsName
// HLS
+ (NSString *)tsNameOfContent:(NSString *)name {
    NSArray<NSString *> *components = [name componentsSeparatedByString:@"_"];
    NSUInteger length = components[0].length + components[1].length + components[2].length + 3;
    return [name substringFromIndex:length];
}

// format: HLS前缀_ts长度_序号_tsName
// HLS
+ (NSUInteger)tsTotalLengthOfContent:(NSString *)name {
    return (NSUInteger)[[name componentsSeparatedByString:@"_"][1] longLongValue];
}

#pragma mark -

+ (NSString *)filenameForUrl:(NSString *)url {
    NSString *name = url.lastPathComponent;
    NSRange range = [name rangeOfString:@"?"];
    if ( range.location != NSNotFound ) {
        name = [name substringToIndex:range.location];
    }
    return name;
}
@end


@implementation MCSFileManager (HLS_Index)

+ (nullable NSString *)hls_indexFilePathInResource:(NSString *)resourceName {
    NSString *filename = @"index.m3u8";
    return [self getFilePathWithName:filename inResource:resourceName];
}

@end


#pragma mark -

@implementation MCSFileManager (HLS_AESKey)
+ (nullable NSString *)hls_createContentFileInResource:(NSString *)resourceName AESKeyName:(NSString *)AESKeyName totalLength:(NSUInteger)totalLength {
    [self lock];
    @try {
        NSUInteger sequence = 0;
        while (true) {
            // format: HLS前缀_ts长度_序号_AESKeyName
            //
            NSString *filename = [NSString stringWithFormat:@"%@_%lu_%lu_%@", HLSPrefix, (unsigned long)totalLength, (unsigned long)sequence++, AESKeyName];
            NSString *filepath = [self getFilePathWithName:filename inResource:resourceName];
            if ( ![NSFileManager.defaultManager fileExistsAtPath:filepath] ) {
                [NSFileManager.defaultManager createFileAtPath:filepath contents:nil attributes:nil];
                return filename;
            }
        }
        return nil;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}


// format: resourceName_AESKeyName.key
+ (nullable NSString *)hls_AESKeyNameForUrl:(NSString *)url inResource:(NSString *)resource {
    return nil;
}

// format: resourceName_aes_seq.key
+ (nullable NSString *)hls_AESKeyFilenameAtIndex:(NSInteger)index inResource:(NSString *)resource {
    return [NSString stringWithFormat:@"%@_aes_%ld.key", resource, (long)index];
}

// format: resourceName_aes_seq.key
+ (nullable NSString *)hls_AESKeyFilePathForAESKeyProxyURL:(NSURL *)URL inResource:(NSString *)resource {
    NSString *filename = [self filenameForUrl:URL.absoluteString];
    return [self getFilePathWithName:filename inResource:resource];
}

// format: resourceName_aes_seq.key
+ (nullable NSString *)hls_resourceNameForAESKeyProxyURL:(NSURL *)URL {
    return [URL.lastPathComponent componentsSeparatedByString:@"_"].firstObject;
}

@end

@implementation MCSFileManager (HLS_TS)
+ (nullable NSString *)hls_tsNameForURL:(NSURL *)URL {
    return URL.absoluteString.mcs_fname;
}

// format: resourceName_tsName
+ (nullable NSString *)hls_tsNameForUrl:(NSString *)url inResource:(nonnull NSString *)resource {
    NSString *filename = [self filenameForUrl:url];
    return [NSString stringWithFormat:@"%@_%@", resource, filename];
}
+ (nullable NSString *)hls_tsNameForTsProxyURL:(NSURL *)URL {
    return [self filenameForUrl:URL.absoluteString];
}
+ (nullable NSString *)hls_tsFragmentsFilePathInResource:(NSString *)resourceName {
    NSString *filename = @"fragments.plist";
    return [self getFilePathWithName:filename inResource:resourceName];
}
+ (nullable NSString *)hls_tsNamesFilePathInResource:(NSString *)resourceName {
    NSString *filename = @"names.plist";
    return [self getFilePathWithName:filename inResource:resourceName];
}
// format: resourceName_tsName
+ (nullable NSString *)hls_resourceNameForTsProxyURL:(NSURL *)URL {
    return [[self hls_tsNameForTsProxyURL:URL] componentsSeparatedByString:@"_"].firstObject;
}
@end



#pragma mark -


@implementation MCSFileManager (Create)

// VOD
//      注意: 返回文件名
+ (nullable NSString *)vod_createContentFileInResource:(NSString *)resourceName atOffset:(NSUInteger)offset pathExtension:(nullable NSString *)pathExtension {
    [self lock];
    @try {
        NSUInteger sequence = 0;
        while (true) {
            // VOD前缀_偏移量_序号.扩展名
            NSString *filename = [NSString stringWithFormat:@"%@_%lu_%lu", VODPrefix, (unsigned long)offset, (unsigned long)sequence++];
            if ( pathExtension.length != 0 ) filename = [filename stringByAppendingPathExtension:pathExtension];
            NSString *filepath = [self getFilePathWithName:filename inResource:resourceName];
            if ( ![NSFileManager.defaultManager fileExistsAtPath:filepath] ) {
                [NSFileManager.defaultManager createFileAtPath:filepath contents:nil attributes:nil];
                return filename;
            }
        }
        return nil;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

// HLS
//      注意: 返回文件名
+ (nullable NSString *)hls_createContentFileInResource:(NSString *)resourceName tsName:(NSString *)tsName tsTotalLength:(NSUInteger)length {
    [self lock];
    @try {
        NSUInteger sequence = 0;
        while (true) {
            // format: HLS前缀_ts长度_序号_tsName
            //
            NSString *filename = [NSString stringWithFormat:@"%@_%lu_%lu_%@", HLSPrefix, (unsigned long)length, (unsigned long)sequence++, tsName];
            NSString *filepath = [self getFilePathWithName:filename inResource:resourceName];
            if ( ![NSFileManager.defaultManager fileExistsAtPath:filepath] ) {
                [NSFileManager.defaultManager createFileAtPath:filepath contents:nil attributes:nil];
                return filename;
            }
        }
        return nil;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}
@end

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


@implementation NSString (MCSFileManagerExtended)
- (NSString *)mcs_fname {
    NSString *name = self.lastPathComponent;
    NSRange range = [name rangeOfString:@"?"];
    if ( range.location != NSNotFound ) {
        name = [name substringToIndex:range.location];
    }
    return name;
}
@end

@implementation NSURL (MCSFileManagerExtended)
- (NSString *)mcs_fname {
    return self.absoluteString.mcs_fname;
}
@end
