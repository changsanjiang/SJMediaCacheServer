//
//  SJResource.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResource.h"
#import "SJResourceDefines.h"
#import "SJResourceReader.h"
#import "SJResourceFileDataReader.h"
#import "SJResourceNetworkDataReader.h"
#import "SJResourcePartialContent.h"
#import "SJResourceManager.h"
#import "SJResourceFileManager.h"

@interface SJResource ()<NSLocking>
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
#warning next 考虑一下文件的合并
    return [SJResourceReader.alloc initWithResource:self request:request];
}

#pragma mark -

- (void)addContents:(nullable NSMutableArray<SJResourcePartialContent *> *)contents {
    if ( contents.count != 0 ) {
        [self lock];
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
