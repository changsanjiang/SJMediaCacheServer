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

- (instancetype)init {
    self = [super init];
    if ( self ) {
        _semaphore = dispatch_semaphore_create(1);
    }
    return self;
}

- (id<SJResourceReader>)readDataWithRequest:(SJDataRequest *)request {
    [self lock];
    @try {
        // length经常变动, 就在这里排序吧
        __auto_type contents = [_contents sortedArrayUsingComparator:^NSComparisonResult(SJResourcePartialContent *obj1, SJResourcePartialContent *obj2) {
            if ( obj1.offset == obj2.offset )
                return obj1.length >= obj2.length ? NSOrderedAscending : NSOrderedDescending;
            return obj1.offset < obj2.offset ? NSOrderedAscending : NSOrderedDescending;
        }];

        NSMutableArray<id<SJResourceDataReader>> *readers = NSMutableArray.array;
        NSRange current = request.range;
        for ( SJResourcePartialContent *content in contents ) {
            NSRange available = NSMakeRange(content.offset, content.length);
            NSRange intersection = NSIntersectionRange(current, available);
            if ( intersection.length != 0 ) {
                // undownloaded part
                NSRange leftRange = NSMakeRange(current.location, intersection.location - current.location);
                if ( leftRange.length != 0 ) {
                    SJResourceNetworkDataReader *reader = [SJResourceNetworkDataReader.alloc initWithURL:request.URL requestHeaders:request.headers range:leftRange];
                    [readers addObject:reader];
                }

                // downloaded part
                NSRange readRange = NSMakeRange(NSMaxRange(leftRange), intersection.length);
                NSString *path = [SJResourceFileManager getContentFilePathWithName:content.name inResource:_name];
                SJResourceFileDataReader *reader = [SJResourceFileDataReader.alloc initWithPath:path readRange:readRange];
                [readers addObject:reader];

                // next part
                current = NSMakeRange(NSMaxRange(intersection), NSMaxRange(request.range) - NSMaxRange(intersection));
            }
            
            if ( current.length == 0 || available.location > NSMaxRange(current) ) break;
        }

        if ( current.length != 0 ) {
            // undownloaded part
            SJResourceNetworkDataReader *reader = [SJResourceNetworkDataReader.alloc initWithURL:request.URL requestHeaders:request.headers range:current];
            [readers addObject:reader];
        }
        
        SJResourceResponse *response = nil;
        if ( _server != nil && _contentType != nil && _totalLength != 0 ) {
            response = [SJResourceResponse.alloc initWithServer:_server contentType:_contentType totalLength:_totalLength contentRange:request.range];
        }
        
        return [SJResourceReader.alloc initWithRequest:request readers:readers presetResponse:response];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

#pragma mark - 

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
