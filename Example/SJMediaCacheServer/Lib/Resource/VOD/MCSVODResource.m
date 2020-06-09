//
//  MCSResource.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSVODResource.h"
#import "MCSResourceDefines.h"
#import "MCSResourceSubclass.h"
#import "MCSVODResource+MCSPrivate.h"
#import "MCSVODReader.h"
#import "MCSVODResourcePartialContent.h"
#import "MCSResourceManager.h"
#import "MCSResourceFileManager.h"
#import "MCSVODResourcePrefetcher.h"
#import "MCSUtils.h"

@interface MCSVODResource ()<NSLocking, MCSVODResourcePartialContentDelegate>
@property (nonatomic, strong) NSMutableArray<MCSVODResourcePartialContent *> *contents;

@property (nonatomic, copy, nullable) NSString *contentType;
@property (nonatomic, copy, nullable) NSString *server;
@property (nonatomic) NSUInteger totalLength;
@end

@implementation MCSVODResource
- (instancetype)init {
    self = [super init];
    if ( self ) {
        _contents = NSMutableArray.array;
    }
    return self;
}

- (void)setName:(NSString *)name {
    [super setName:name];
    
    [self lock];
    __auto_type contents = [MCSResourceFileManager getContentsInResource:name];
    [contents makeObjectsPerformSelector:@selector(setDelegate:) withObject:self];
    [_contents addObjectsFromArray:contents];
    [self unlock];
}

- (MCSResourceType)type {
    return MCSResourceTypeVOD;
}

- (id<MCSResourceReader>)readerWithRequest:(NSURLRequest *)request {
    return [MCSVODReader.alloc initWithResource:self request:request];
}

- (id<MCSResourcePrefetcher>)prefetcherWithRequest:(NSURLRequest *)request {
    return [MCSVODResourcePrefetcher.alloc initWithResource:self request:request];
}

#pragma mark -

- (NSString *)filePathOfContent:(MCSVODResourcePartialContent *)content {
    return [MCSResourceFileManager getContentFilePathWithName:content.name inResource:self.name];
}

- (MCSVODResourcePartialContent *)createContentWithOffset:(NSUInteger)offset {
    [self lock];
    @try {
        NSString *filename = [MCSResourceFileManager createContentFileInResource:self.name atOffset:offset];
        MCSVODResourcePartialContent *content = [MCSVODResourcePartialContent.alloc initWithName:filename offset:offset];
        content.delegate = self;
        [_contents addObject:content];
        return content;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}
 
- (NSUInteger)totalLength {
    [self lock];
    @try {
        return _totalLength;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}
 
- (NSString *)contentType {
    [self lock];
    @try {
        return _contentType;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}
 
- (NSString *)server {
    [self lock];
    @try {
        return _server;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)setServer:(NSString * _Nullable)server contentType:(NSString * _Nullable)contentType totalLength:(NSUInteger)totalLength {
    BOOL updated = NO;
    [self lock];
    if ( ![server isEqualToString:_server] ) {
        _server = server.copy;
        updated = YES;
    }
    
    if ( ![contentType isEqualToString:_contentType] ) {
        _contentType = contentType;
        updated = YES;
    }
    
    if ( _totalLength != totalLength ) {
        _totalLength = totalLength;
        updated = YES;
    }
    [self unlock];
    if ( updated ) {
        [MCSResourceManager.shared saveMetadata:self];
    }
}

- (void)readWriteCountDidChangeForPartialContent:(MCSVODResourcePartialContent *)content {
    if ( content.readWriteCount > 0 ) return;
    [self lock];
    @try {
        if ( _contents.count <= 1 ) return;
        
        // 合并文件
        NSMutableArray<MCSVODResourcePartialContent *> *list = NSMutableArray.alloc.init;
        for ( MCSVODResourcePartialContent *content in _contents ) {
            if ( content.readWriteCount == 0 )
                [list addObject:content];
        }
        
        NSMutableArray<MCSVODResourcePartialContent *> *deleteContents = NSMutableArray.alloc.init;
        [list sortUsingComparator:^NSComparisonResult(MCSVODResourcePartialContent *obj1, MCSVODResourcePartialContent *obj2) {
            NSRange range1 = NSMakeRange(obj1.offset, obj1.length);
            NSRange range2 = NSMakeRange(obj2.offset, obj2.length);
            
            // 1 包含 2
            if ( MCSNSRangeContains(range1, range2) ) {
                if ( ![deleteContents containsObject:obj2] ) [deleteContents addObject:obj2];
            }
            // 2 包含 1
            else if ( MCSNSRangeContains(range2, range1) ) {
                if ( ![deleteContents containsObject:obj1] ) [deleteContents addObject:obj1];;
            }
            
            return range1.location < range2.location ? NSOrderedAscending : NSOrderedDescending;
        }];
        
        if ( deleteContents.count != 0 ) [list removeObjectsInArray:deleteContents];

        for ( NSInteger i = 0 ; i < list.count - 1; i += 2 ) {
            MCSVODResourcePartialContent *write = list[i];
            MCSVODResourcePartialContent *read  = list[i + 1];
            NSRange readRange = NSMakeRange(0, 0);

            NSUInteger maxA = write.offset + write.length;
            NSUInteger maxR = read.offset + read.length;
            if ( maxA >= read.offset && maxA < maxR ) // 有交集
                readRange = NSMakeRange(maxA - read.offset, maxR - maxA); // 读取read中未相交的部分

            if ( readRange.length != 0 ) {
                NSFileHandle *writer = [NSFileHandle fileHandleForWritingAtPath:[self filePathOfContent:write]];
                NSFileHandle *reader = [NSFileHandle fileHandleForReadingAtPath:[self filePathOfContent:read]];
                @try {
                    [writer seekToEndOfFile];
                    [reader seekToFileOffset:readRange.location];
                    while (true) {
                        @autoreleasepool {
                            NSData *data = [reader readDataOfLength:1024 * 1024 * 1];
                            if ( data.length == 0 )
                                break;
                            [writer writeData:data];
                        }
                    }
                    [reader closeFile];
                    [writer synchronizeFile];
                    [writer closeFile];
                    write.length += readRange.length;
                    [deleteContents addObject:read];
                } @catch (NSException *exception) {
                    break;
                }
            }
        }
        
        for ( MCSVODResourcePartialContent *content in deleteContents ) {
            NSString *path = [self filePathOfContent:content];
            if ( [NSFileManager.defaultManager removeItemAtPath:path error:NULL] ) {
                [_contents removeObject:content];
            }
        }
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)contentLengthDidChangeForPartialContent:(MCSVODResourcePartialContent *)content {
    [MCSResourceManager.shared didWriteDataForResource:self];
}
@end
