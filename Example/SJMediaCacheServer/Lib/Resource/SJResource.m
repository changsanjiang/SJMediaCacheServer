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
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSMutableArray<SJResourcePartialContent *> *contents;
@end

@implementation SJResource
+ (instancetype)resourceWithURL:(NSURL *)URL {
    return [SJResourceManager.shared resourceWithURL:URL];
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if ( self ) {
        _path = path.copy;
    }
    return self;
}

- (id<SJResourceReader>)readDataWithRequest:(SJDataRequest *)request {
    [self lock];
    @try {
        __auto_type contents = [self.contents sortedArrayUsingComparator:^NSComparisonResult(SJResourcePartialContent *obj1, SJResourcePartialContent *obj2) {
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
                    SJResourceNetworkDataReader *reader = [SJResourceNetworkDataReader.alloc initWithURL:request.URL headers:request.headers range:leftRange];
                    [readers addObject:reader];
                }

                // downloaded part
                NSRange readRange = NSMakeRange(NSMaxRange(leftRange), intersection.length);
                NSString *path = [SJResourceFileManager getContentFilePathWithName:content.name inResource:self.path];
                SJResourceFileDataReader *reader = [SJResourceFileDataReader.alloc initWithPath:path readRange:readRange];
                [readers addObject:reader];

                // next part
                current = NSMakeRange(NSMaxRange(intersection), NSMaxRange(request.range) - NSMaxRange(intersection));
            }
            
            if ( current.length == 0 || available.location > NSMaxRange(current) ) break;
        }

        if ( current.length != 0 ) {
            // undownloaded part
            SJResourceNetworkDataReader *reader = [SJResourceNetworkDataReader.alloc initWithURL:request.URL headers:request.headers range:current];
            [readers addObject:reader];
        }
        return [SJResourceReader.alloc initWithRange:request.range readers:readers];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSString *)createFileWithContent:(SJResourcePartialContent *)content {
    [self lock];
    @try {
        return [SJResourceFileManager createContentFileWithResourcePath:self.path atOffset:content.offset];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (SJResourcePartialContent *)newContentWithOffset:(NSUInteger)offset {
    [self lock];
    @try {
#warning next ...
        return nil;
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
@end
