//
//  HLSAssetContentProvider.m
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/11/25.
//

#import "HLSAssetContentProvider.h"
#import "MCSConsts.h"
#import "NSFileManager+MCS.h"
#import "HLSAssetTsContent.h"

#define HLS_PREFIX_FILENAME   @"hls"
#define HLS_PREFIX_FILENAME1  HLS_PREFIX_FILENAME
#define HLS_PREFIX_FILENAME2 @"hlsr" // range

@implementation HLSAssetContentProvider {
    NSString *mRootDir;
}

- (instancetype)initWithDirectory:(NSString *)directory {
    self = [super init];
    if ( self ) {
        mRootDir = directory;
        if ( ![NSFileManager.defaultManager fileExistsAtPath:mRootDir] ) {
            [NSFileManager.defaultManager createDirectoryAtPath:mRootDir withIntermediateDirectories:YES attributes:nil error:NULL];
        }
    }
    return self;
}

- (NSString *)getPlaylistFilePath {
    return [mRootDir stringByAppendingPathComponent:self.getPlaylistRelativePath];
}

- (NSString *)getPlaylistRelativePath {
    return [NSString stringWithFormat:@"index.%@", HLS_EXTENSION_PLAYLIST];
}

- (NSString *)getAESKeyFilePath:(NSString *)name {
    return [mRootDir stringByAppendingPathComponent:name];
}










- (nullable NSArray<id<HLSAssetTsContent>> *)loadTsContentsWithParser:(HLSAssetParser *)parser {
    NSMutableArray<id<HLSAssetTsContent>> *m = nil;
    for ( NSString *filename in [NSFileManager.defaultManager contentsOfDirectoryAtPath:mRootDir error:NULL] ) {
        if ( ![filename hasPrefix:HLS_PREFIX_FILENAME] )
            continue;
        if ( m == nil )
            m = NSMutableArray.array;
        NSString *filePath = [self _TsContentFilePathForFilename:filename];
        NSString *name = [self _TsNameForFilename:filename];
        id<HLSAssetTsContent>ts = nil;
        long long totalLength = [self _TsTotalLengthForFilename:filename];
        if      ( [filename hasPrefix:HLS_PREFIX_FILENAME2] ) {
            long long length = (long long)[NSFileManager.defaultManager mcs_fileSizeAtPath:filePath];
            NSRange range = [self _TsRangeForFilename:filename];
#warning next ...
//            ts = [HLSAssetTsContent.alloc initWithName:name filePath:filePath totalLength:totalLength length:length rangeInAsset:range];
        }
        else if ( [filename hasPrefix:HLS_PREFIX_FILENAME1] ) {
            long long length = (long long)[NSFileManager.defaultManager mcs_fileSizeAtPath:filePath];
#warning next ...
//            ts = [HLSAssetTsContent.alloc initWithName:name filePath:filePath totalLength:totalLength length:length];
        }
        
        if ( ts != nil )
            [m addObject:ts];
    }
    return m;
}

- (nullable id<HLSAssetTsContent>)createTsContentWithName:(NSString *)name totalLength:(NSUInteger)totalLength {
    NSUInteger number = 0;
    do {
        NSString *filename = [self _TsFilenameWithName:name totalLength:totalLength number:number];
        NSString *filePath = [self _TsContentFilePathForFilename:filename];
        if ( ![NSFileManager.defaultManager fileExistsAtPath:filePath] ) {
            [NSFileManager.defaultManager createFileAtPath:filePath contents:nil attributes:nil];
#warning next ...
//            return [HLSAssetTsContent.alloc initWithName:name filePath:filePath totalLength:totalLength];
        }
        number += 1;
    } while (true);
    return nil;
}

/// #EXTINF:3.951478,
/// #EXT-X-BYTERANGE:1544984@1007868
///
/// range
- (nullable id<HLSAssetTsContent>)createTsContentWithName:(NSString *)name totalLength:(NSUInteger)totalLength rangeInAsset:(NSRange)range {
    NSUInteger number = 0;
    do {
        NSString *filename = [self _TsFilenameWithName:name totalLength:totalLength rangeInAsset:range number:number];
        NSString *filePath = [self _TsContentFilePathForFilename:filename];
        if ( ![NSFileManager.defaultManager fileExistsAtPath:filePath] ) {
            [NSFileManager.defaultManager createFileAtPath:filePath contents:nil attributes:nil];
#warning next ...
//            return [HLSAssetTsContent.alloc initWithName:name filePath:filePath totalLength:totalLength rangeInAsset:range];
        }
        number += 1;
    } while (true);
    return nil;
}

- (nullable NSString *)TsContentFilePath:(HLSAssetTsContent *)content {
    return content.filePath;
}

- (void)removeTsContent:(HLSAssetTsContent *)content {
    [NSFileManager.defaultManager removeItemAtPath:content.filePath error:NULL];
}

#pragma mark - mark

- (NSString *)_TsFilenameWithName:(NSString *)name totalLength:(long long)totalLength number:(NSInteger)number {
    // _FILE_NAME1(__prefix__, __totalLength__, __number__, __TsName__)
    return [NSString stringWithFormat:@"%@_%lld_%ld_%@", HLS_PREFIX_FILENAME1, totalLength, (long)number, name];
}

- (NSString *)_TsFilenameWithName:(NSString *)name totalLength:(NSUInteger)totalLength rangeInAsset:(NSRange)range number:(NSInteger)number {
    // _FILE_NAME2(__prefix__, __totalLength__, __offset__, __number__, __TsName__)
    return [NSString stringWithFormat:@"%@_%lu_%lu_%lu_%ld_%@", HLS_PREFIX_FILENAME2, (unsigned long)totalLength, (unsigned long)range.location, (unsigned long)range.length, (long)number, name];
}

#pragma mark -

- (nullable NSString *)_TsContentFilePathForFilename:(NSString *)filename {
    return [mRootDir stringByAppendingPathComponent:filename];
}

- (NSString *)_TsNameForFilename:(NSString *)filename {
    return [filename componentsSeparatedByString:@"_"].lastObject;
}

- (long long)_TsTotalLengthForFilename:(NSString *)filename {
    return [[filename componentsSeparatedByString:@"_"][1] longLongValue];;
}

- (NSRange)_TsRangeForFilename:(NSString *)filename {
    NSArray<NSString *> *contents = [filename componentsSeparatedByString:@"_"];
    return NSMakeRange(contents[2].longLongValue, contents[3].longLongValue);
}
@end
