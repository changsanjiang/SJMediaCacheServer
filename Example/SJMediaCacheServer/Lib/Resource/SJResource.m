//
//  SJResource.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResource.h"
#import "SJResourceDefines.h"
#import "SJResource+SJPrivate.h"
#import "SJResourceReader.h"
#import "SJResourceFileDataReader.h"
#import "SJResourceNetworkDataReader.h"
#import "SJResourcePartialContent.h"
#import "SJResourceManager.h"
#import "SJResourceFileManager.h"
#import "SJUtils.h"

@interface SJResource ()<NSLocking, SJResourcePartialContentDelegate>
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
@property (nonatomic) NSInteger id;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) NSMutableArray<SJResourcePartialContent *> *contents;

@property (nonatomic, copy, nullable) NSString *contentType;
@property (nonatomic, copy, nullable) NSString *server;
@property (nonatomic) NSUInteger totalLength;
@end

@implementation SJResource
+ (instancetype)resourceWithURL:(NSURL *)URL {
    return [SJResourceManager.shared resourceWithURL:URL];
}

- (instancetype)initWithName:(NSString *)name {
    self = [self init];
    if ( self ) {
        _name = name;
    }
    return self;
}

- (instancetype)init {
    self = [super init];
    if ( self ) {
        _contents = NSMutableArray.array;
        _semaphore = dispatch_semaphore_create(1);
    }
    return self;
}

- (id<SJResourceReader>)readDataWithRequest:(SJDataRequest *)request {
    return [SJResourceReader.alloc initWithResource:self request:request];
}

#pragma mark -

- (void)addContents:(nullable NSMutableArray<SJResourcePartialContent *> *)contents {
    if ( contents.count != 0 ) {
        [self lock];
        [contents makeObjectsPerformSelector:@selector(setDelegate:) withObject:self];
        [_contents addObjectsFromArray:contents];
        [self unlock];
    }
}

- (NSString *)filePathOfContent:(SJResourcePartialContent *)content {
    return [SJResourceFileManager getContentFilePathWithName:content.name inResource:self.name];
}

- (SJResourcePartialContent *)createContentWithOffset:(NSUInteger)offset {
    [self lock];
    @try {
        NSString *filename = [SJResourceFileManager createContentFileInResource:_name atOffset:offset];
        SJResourcePartialContent *content = [SJResourcePartialContent.alloc initWithName:filename offset:offset];
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
        [SJResourceManager.shared update:self];
    }
}

- (void)partialContent:(SJResourcePartialContent *)content referenceCountDidChange:(NSUInteger)referenceCount {
    if ( referenceCount > 0 ) return;
    [self lock];
    @try {
        if ( _contents.count <= 1 ) return;
        
        // 合并文件
        NSMutableArray<SJResourcePartialContent *> *list = NSMutableArray.array;
        for ( SJResourcePartialContent *content in _contents ) {
            if ( content.referenceCount == 0 )
                [list addObject:content];
        }
        
        NSMutableArray<SJResourcePartialContent *> *deleteContents = NSMutableArray.array;
        [list sortUsingComparator:^NSComparisonResult(SJResourcePartialContent *obj1, SJResourcePartialContent *obj2) {
            NSRange range1 = NSMakeRange(obj1.offset, obj1.length);
            NSRange range2 = NSMakeRange(obj2.offset, obj2.length);
            
            // 1 包含 2
            if ( SJNSRangeContains(range1, range2) && ![deleteContents containsObject:obj2] )
                [deleteContents addObject:obj2];
            
            // 2 包含 1
            if ( SJNSRangeContains(range2, range1) && ![deleteContents containsObject:obj1] )
                [deleteContents addObject:obj1];
            
            return range1.location < range2.location ? NSOrderedAscending : NSOrderedDescending;
        }];
        
        if ( deleteContents.count != 0 ) [list removeObjectsInArray:deleteContents];

        for ( NSInteger i = 0 ; i < list.count - 1; i += 2 ) {
            SJResourcePartialContent *write = list[i];
            SJResourcePartialContent *read  = list[i + 1];
            NSRange readRange = NSMakeRange(0, 0);

            NSUInteger maxA = write.offset + write.length;
            NSUInteger maxR = read.offset + read.length;
            if ( maxA >= read.offset && maxA < maxR ) // 有交集
                readRange = NSMakeRange(maxA - read.offset, maxR - maxA); // 减去有交集的部分

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
                    [deleteContents addObject:read];
                } @catch (NSException *exception) {
                    break;
                }
            }
        }
        
        for ( SJResourcePartialContent *content in deleteContents ) {
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

#pragma mark -

- (void)lock {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
}

- (void)unlock {
    dispatch_semaphore_signal(_semaphore);
}

- (void)callbackWithBlock:(void(^)(void))block {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if ( block ) block();
    });
}
@end
