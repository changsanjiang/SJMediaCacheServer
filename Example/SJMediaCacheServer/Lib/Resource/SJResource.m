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
    [self lock];
    @try {
        // 合并文件
        NSMutableArray<SJResourcePartialContent *> *merge = NSMutableArray.array;
        for ( SJResourcePartialContent *content in _contents ) {
            if ( content.referenceCount == 0 )
                [merge addObject:content];
        }
        
        [merge sortUsingComparator:^NSComparisonResult(SJResourcePartialContent *obj1, SJResourcePartialContent *obj2) {
            if ( obj1.offset < obj2.offset )
                return NSOrderedAscending;
            if ( obj1.offset == obj2.offset && obj1.length > obj2.length )
                return NSOrderedAscending;
            return NSOrderedDescending;
        }];
        
        NSMutableArray<SJResourcePartialContent *> *delete = NSMutableArray.array;
        for ( NSInteger i = 0 ; i < merge.count ; ++ i ) {
            SJResourcePartialContent *c1 = merge[i];
            for ( NSInteger j = i ; j < merge.count ; ++ j ) {
                SJResourcePartialContent *c2 = merge[j];
                NSRange range1 = NSMakeRange(c1.offset, c1.length);
                NSRange range2 = NSMakeRange(c2.offset, c2.length);
                if      ( SJNSRangeContains(range1, range2) ) {
                    [delete addObject:c2];
                    continue;
                }
                else if ( SJNSRangeContains(range2, range1) ) {
                    [delete addObject:c1];
                    continue;
                }
                
                SJResourcePartialContent *write = range1.location < range2.location ? c1 : c2;
                SJResourcePartialContent *read  = write == c1 ? c2 : c1;
                NSRange loadRange = NSMakeRange(0, 0);

                NSUInteger w = write.offset + write.length;
                NSUInteger r = read.offset + read.length;
                if ( w >= read.offset && w < r ) // 有交集
                    loadRange = NSMakeRange(w, r - w);
                    
#warning next ... 删除拼接的情况
                
                if ( loadRange.length != 0 ) {
                    NSFileHandle *writer = [NSFileHandle fileHandleForWritingAtPath:[self filePathOfContent:write]];
                    NSFileHandle *reader = [NSFileHandle fileHandleForReadingAtPath:[self filePathOfContent:read]];
                    @try {
                        [writer seekToEndOfFile];
                        [reader seekToFileOffset:loadRange.location - read.offset];
                    } @catch (NSException *exception) {
                        continue;
                    }
                    while (true) {
                        @autoreleasepool {
                            NSData *data = [reader readDataOfLength:1024 * 1024 * 1];
                            if ( data.length == 0 )
                                break;
                            @try {
                                [writer writeData:data];
                            } @catch (__unused NSException *exception) {
                                break;
                            }
                        }
                    }
                    [reader closeFile];
                    
                    @try {
                        [writer synchronizeFile];
                        [writer closeFile];
                    } @catch (__unused NSException *exception) {
                        continue;
                    }
                }
            }
            
            [_contents removeObjectsInArray:delete];
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
