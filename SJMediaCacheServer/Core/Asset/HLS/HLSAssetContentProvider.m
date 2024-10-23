//
//  HLSAssetContentProvider.m
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/11/25.
//

#import "HLSAssetContentProvider.h"
#import "MCSConsts.h"
#import "NSFileManager+MCS.h"
#import "HLSAssetSegment.h"

#define SEGMENT_FILE_NAME_PREFIX   @"hls"
#define SEGMENT_FILE_NAME_PREFIX1  SEGMENT_FILE_NAME_PREFIX
#define SEGMENT_FILE_NAME_PREFIX2  @"hlsr" // byte range

#define INIT_FILE_NAME_PREFIX @"xmap"
#define INIT_FILE_NAME_PREFIX1 INIT_FILE_NAME_PREFIX
#define INIT_FILE_NAME_PREFIX2 @"xmapr" // byte range

@implementation HLSAssetContentProvider {
    NSString *mRootDir;
    BOOL mDirCreated;
}

- (instancetype)initWithDirectory:(NSString *)directory {
    self = [super init];
    if ( self ) {
        mRootDir = directory;
        mDirCreated = [NSFileManager.defaultManager fileExistsAtPath:mRootDir];
    }
    return self;
}

- (NSString *)getPlaylistFilePath {
    return [mRootDir stringByAppendingPathComponent:[NSString stringWithFormat:@"index.%@", HLS_EXTENSION_PLAYLIST]];
}

- (nullable NSString *)loadPlaylistFilePath {
    NSString *filePath = [self getPlaylistFilePath];
    return [NSFileManager.defaultManager fileExistsAtPath:filePath] ? filePath : nil;
}
- (nullable NSString *)writeContentsToPlaylist:(NSString *)contents error:(out NSError **)errorPtr {
    NSError *error = nil;
    NSData *data = [contents dataUsingEncoding:NSUTF8StringEncoding];
    if ( [self _createDir:&error] ) {
        NSString *filePath = [self getPlaylistFilePath];
        if ( [data writeToFile:filePath options:NSDataWritingAtomic error:&error] ) {
            return filePath;
        }
    }
    if ( error != nil && errorPtr != NULL ) *errorPtr = error;
    return nil;
}

- (NSString *)getAESKeyFilePath:(NSString *)filename {
    return [mRootDir stringByAppendingPathComponent:filename];
}

- (nullable NSString *)loadAESKeyFilePathForIdentifier:(NSString *)identifier {
    NSString *filePath = [self getAESKeyFilePath:identifier];
    return [NSFileManager.defaultManager fileExistsAtPath:filePath] ? filePath : nil;
}
- (nullable NSString *)writeDataToAESKey:(NSData *)data forIdentifier:(NSString *)identifier error:(out NSError **)errorPtr {
    NSError *error = nil;
    if ( [self _createDir:&error] ) {
        NSString *filePath = [self getAESKeyFilePath:identifier];
        if ( [data writeToFile:filePath options:NSDataWritingAtomic error:&error] ) {
            return filePath;
        }
    }
    if ( error != nil && errorPtr != NULL ) *errorPtr = error;
    return nil;
}

- (NSString *)getSubtitlesFilePath:(NSString *)filename {
    return [mRootDir stringByAppendingPathComponent:filename];
}

- (nullable NSString *)loadSubtitlesFilePathForIdentifier:(NSString *)identifier {
    NSString *filePath = [self getSubtitlesFilePath:identifier];
    return [NSFileManager.defaultManager fileExistsAtPath:filePath] ? filePath : nil;
}
- (nullable NSString *)writeDataToSubtitles:(NSData *)data forIdentifier:(NSString *)identifier error:(out NSError **)errorPtr {
    NSError *error = nil;
    if ( [self _createDir:&error] ) {
        NSString *filePath = [self getSubtitlesFilePath:identifier];
        if ( [data writeToFile:filePath options:NSDataWritingAtomic error:&error] ) {
            return filePath;
        }
    }
    if ( error != nil && errorPtr != NULL ) *errorPtr = error;
    return nil;
}

- (nullable NSArray<NSString *> *)loadInitializationFilenames {
    NSMutableArray<NSString *> *m = nil;
    for ( NSString *filename in [NSFileManager.defaultManager contentsOfDirectoryAtPath:mRootDir error:NULL] ) {
        if ( [filename hasPrefix:INIT_FILE_NAME_PREFIX] ) {
            if ( m == nil ) m = NSMutableArray.array;
            [m addObject:filename];
        }
    }
    return m;
}
- (NSString *)getInitializationIdentifierByFilename:(NSString *)filename byteRange:(NSRange *)byteRangePtr {
    return [self _getIdentifierByFilename:filename totalLength:NULL byteRange:byteRangePtr];
}
- (nullable NSString *)writeDataToInitialization:(NSData *)data forIdentifier:(NSString *)identifier error:(out NSError **)error {
    return [self writeDataToInitialization:data forIdentifier:identifier byteRange:NSMakeRange(NSNotFound, NSNotFound) error:error];
}
- (nullable NSString *)writeDataToInitialization:(NSData *)data forIdentifier:(NSString *)identifier byteRange:(NSRange)byteRange error:(out NSError **)errorPtr {
    NSError *error = nil;
    if ( [self _createDir:&error] ) {
        BOOL isSubrange = byteRange.location != NSNotFound;
        NSString *filename = !isSubrange ? [self _generateFilenameWithPrefix:INIT_FILE_NAME_PREFIX1 identifier:identifier totalLength:0 number:0] :
                                           [self _generateFilenameWithPrefix:INIT_FILE_NAME_PREFIX2 identifier:identifier totalLength:0 number:0 byteRange:byteRange];
        NSString *filePath = [mRootDir stringByAppendingPathComponent:filename];
        if ( [data writeToFile:filePath options:NSDataWritingAtomic error:&error] ) {
            return filePath;
        }
    }
    if ( error != nil && errorPtr != NULL ) *errorPtr = error;
    return nil;
}


- (nullable NSArray<NSString *> *)loadSegmentFilenames {
    NSMutableArray<NSString *> *m = nil;
    for ( NSString *filename in [NSFileManager.defaultManager contentsOfDirectoryAtPath:mRootDir error:NULL] ) {
        if ( [filename hasPrefix:SEGMENT_FILE_NAME_PREFIX] ) {
            if ( m == nil ) m = NSMutableArray.array;
            [m addObject:filename];
        }
    }
    return m;
}

- (NSString *)getSegmentIdentifierByFilename:(NSString *)filename byteRange:(NSRange *)byteRangePtr {
    return [self _getIdentifierByFilename:filename totalLength:NULL byteRange:byteRangePtr];
}

- (id<HLSAssetSegment>)getSegmentByFilename:(NSString *)filename mimeType:(nullable NSString *)mimeType {
    NSString *filePath = [mRootDir stringByAppendingPathComponent:filename];
    UInt64 totalLength = 0;
    NSRange byteRange = { NSNotFound, NSNotFound };
    [self _getIdentifierByFilename:filename totalLength:&totalLength byteRange:&byteRange];
    BOOL isSubrange = byteRange.location != NSNotFound;
    UInt64 length = [NSFileManager.defaultManager mcs_fileSizeAtPath:filePath];
    return !isSubrange ? [HLSAssetSegment.alloc initWithMimeType:mimeType filePath:filePath totalLength:totalLength length:length] :
                         [HLSAssetSegment.alloc initWithMimeType:mimeType filePath:filePath totalLength:totalLength length:length byteRange:byteRange];
}

- (nullable id<HLSAssetSegment>)createSegmentWithIdentifier:(NSString *)identifier mimeType:(nullable NSString *)mimeType totalLength:(NSUInteger)totalLength error:(NSError **)error {
    return [self createSegmentWithIdentifier:identifier mimeType:mimeType totalLength:totalLength byteRange:NSMakeRange(NSNotFound, NSNotFound) error:error];
}

- (nullable id<HLSAssetSegment>)createSegmentWithIdentifier:(NSString *)identifier mimeType:(nullable NSString *)mimeType totalLength:(NSUInteger)totalLength byteRange:(NSRange)byteRange error:(NSError **)errorPtr {
    NSError *error = nil;
    if ( [self _createDir:&error] ) {
        BOOL isSubrange = byteRange.location != NSNotFound;
        NSUInteger number = 0;
        do {
            NSString *filename = !isSubrange ? [self _generateFilenameWithPrefix:SEGMENT_FILE_NAME_PREFIX1 identifier:identifier totalLength:totalLength number:number] :
                                               [self _generateFilenameWithPrefix:SEGMENT_FILE_NAME_PREFIX2 identifier:identifier totalLength:totalLength number:number byteRange:byteRange];
            NSString *filePath = [mRootDir stringByAppendingPathComponent:filename];
            if ( ![NSFileManager.defaultManager fileExistsAtPath:filePath] ) {
                [NSFileManager.defaultManager createFileAtPath:filePath contents:nil attributes:nil];
                return !isSubrange ? [HLSAssetSegment.alloc initWithMimeType:mimeType filePath:filePath totalLength:totalLength] :
                [HLSAssetSegment.alloc initWithMimeType:mimeType filePath:filePath totalLength:totalLength byteRange:byteRange];
            }
            number += 1;
        } while (true);
    }
    if ( error != nil && errorPtr != NULL ) *errorPtr = error;
    return nil;
}

- (void)removeSegment:(HLSAssetSegment *)content {
    [NSFileManager.defaultManager removeItemAtPath:content.filePath error:NULL];
}

- (void)clear {
    [NSFileManager.defaultManager removeItemAtPath:mRootDir error:NULL];
}

#pragma mark - mark

- (BOOL)_createDir:(NSError **)errorPtr {
    if ( !mDirCreated ) mDirCreated = [NSFileManager.defaultManager createDirectoryAtPath:mRootDir withIntermediateDirectories:YES attributes:nil error:errorPtr];
    return mDirCreated;
}

// e.g., _FILE_NAME1(__prefix__, __segmentTotalLength__, __number__, __ID__)
- (NSString *)_generateFilenameWithPrefix:(NSString *)prefix identifier:(NSString *)identifier totalLength:(long long)totalLength number:(NSInteger)number {
    return [NSString stringWithFormat:@"%@_%lld_%ld_%@", prefix, totalLength, (long)number, identifier];
}

// e.g., _FILE_NAME2(__prefix__, __resourceTotalLength__, __location__, __length__, __number__, __ID__)
- (NSString *)_generateFilenameWithPrefix:(NSString *)prefix identifier:(NSString *)identifier totalLength:(NSUInteger)totalLength number:(NSInteger)number byteRange:(NSRange)range {
    return [NSString stringWithFormat:@"%@_%lu_%lu_%lu_%ld_%@", prefix, (unsigned long)totalLength, (unsigned long)range.location, (unsigned long)range.length, (long)number, identifier];
}

// _FILE_NAME1(__prefix__, __segmentTotalLength__, __number__, __ID__)
// _FILE_NAME2(__prefix__, __resourceTotalLength__, __location__, __length__, __number__, __ID__)
- (NSString *)_getIdentifierByFilename:(NSString *)filename totalLength:(UInt64 *)totalLengthPtr byteRange:(NSRange *)byteRangePtr {
    // separator: @"_"
    NSArray<NSString *> *components = [filename componentsSeparatedByString:@"_"];
    if ( totalLengthPtr != NULL ) {
        *totalLengthPtr = [components[1] longLongValue];
    }
    
    if ( components.count == 6 ) { // has byte range
        if ( byteRangePtr != NULL ) {
            NSUInteger location = [components[2] longLongValue];
            NSUInteger length = [components[3] longLongValue];
            *byteRangePtr = NSMakeRange(location, length);
        }
    }
    return components.lastObject;
}
@end
