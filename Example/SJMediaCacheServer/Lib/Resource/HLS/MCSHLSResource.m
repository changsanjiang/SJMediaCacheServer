//
//  MCSHLSResource.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSResource.h"
#import "MCSResourceManager.h"
#import "MCSHLSReader.h"
#import "MCSHLSParser.h"
#import "MCSResourceSubclass.h"
#import "MCSHLSResource+MCSPrivate.h"
#import "MCSResourceFileManager.h"

@interface MCSHLSResource ()<MCSResourcePartialContentDelegate>
@property (nonatomic, strong, nullable) MCSHLSParser *parser;
@property (nonatomic, strong, nullable) NSMutableArray<MCSResourcePartialContent *> *contents;
@end

@implementation MCSHLSResource

- (instancetype)init {
    self = [super init];
    if ( self ) {
        _contents = NSMutableArray.array;
    }
    return self;
}

- (MCSResourceType)type {
    return MCSResourceTypeHLS;
}

- (id<MCSResourceReader>)readerWithRequest:(NSURLRequest *)request {
    return [MCSHLSReader.alloc initWithResource:self request:request];
}

- (id<MCSResourcePrefetcher>)prefetcherWithRequest:(NSURLRequest *)request {
    return nil;
}

- (MCSResourcePartialContent *)contentForTsURL:(NSURL *)URL {
    [self lock];
    @try {
        NSString *tsName = [MCSResourceFileManager hls_tsNameForUrl:URL.absoluteString];
        for ( MCSResourcePartialContent *content in _contents ) {
            if ( [content.tsName isEqualToString:tsName] ) {
                NSString *contentPath = [MCSResourceFileManager getFilePathWithName:content.name inResource:self.name];
                NSUInteger length = [NSFileManager.defaultManager attributesOfItemAtPath:contentPath error:NULL].fileSize;
                if ( length == content.tsTotalLength )
                    return content;
            }
        }
        return nil;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSString *)filePathOfContent:(MCSResourcePartialContent *)content {
    return [MCSResourceFileManager getFilePathWithName:content.name inResource:self.name];
}

- (MCSResourcePartialContent *)createContentWithTsURL:(NSURL *)URL tsContentType:(NSString *)tsContentType tsTotalLength:(NSUInteger)totalLength {
    [self lock];
    @try {
        NSString *tsName = [MCSResourceFileManager hls_tsNameForUrl:URL.absoluteString];
        NSString *filename = [MCSResourceFileManager hls_createContentFileInResource:self.name tsName:tsName tsContentType:tsContentType tsTotalLength:totalLength];
        MCSResourcePartialContent *content = [MCSResourcePartialContent.alloc initWithName:filename tsName:tsName tsContentType:tsContentType tsTotalLength:totalLength length:0];
        content.delegate = self;
        [_contents addObject:content];
        return content;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

@synthesize parser = _parser;
- (void)setParser:(MCSHLSParser *)parser {
    [self lock];
    _parser = parser;
    [self unlock];
}

- (MCSHLSParser *)parser {
    [self lock];
    @try {
        return _parser;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)readWriteCountDidChangeForPartialContent:(MCSResourcePartialContent *)content {
#ifdef DEBUG
    NSLog(@"%d - -[%@ %s]", (int)__LINE__, NSStringFromClass([self class]), sel_getName(_cmd));
#endif
}

- (void)contentLengthDidChangeForPartialContent:(MCSResourcePartialContent *)content {
#ifdef DEBUG
    NSLog(@"%d - -[%@ %s]", (int)__LINE__, NSStringFromClass([self class]), sel_getName(_cmd));
#endif
}
@end
