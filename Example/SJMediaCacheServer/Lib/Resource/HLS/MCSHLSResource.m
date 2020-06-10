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
#import "MCSFileManager.h"

@interface MCSHLSResource ()

@end

@implementation MCSHLSResource

- (MCSResourceType)type {
    return MCSResourceTypeHLS;
}

- (id<MCSResourceReader>)readerWithRequest:(NSURLRequest *)request {
    return [MCSHLSReader.alloc initWithResource:self request:request];
}

- (id<MCSResourcePrefetcher>)prefetcherWithRequest:(NSURLRequest *)request {
    return nil;
}

- (NSString *)tsNameForTsProxyURL:(NSURL *)URL {
    return [MCSFileManager hls_tsNameForTsProxyURL:URL];
}

- (MCSResourcePartialContent *)contentForTsProxyURL:(NSURL *)URL {
    [self lock];
    @try {
        NSString *tsName = [MCSFileManager hls_tsNameForTsProxyURL:URL];
        for ( MCSResourcePartialContent *content in self.contents ) {
            if ( [content.tsName isEqualToString:tsName] ) {
                NSString *contentPath = [MCSFileManager getFilePathWithName:content.name inResource:self.name];
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
    return [MCSFileManager getFilePathWithName:content.name inResource:self.name];
}

- (MCSResourcePartialContent *)createContentWithTsProxyURL:(NSURL *)proxyURL tsTotalLength:(NSUInteger)totalLength {
    [self lock];
    @try {
        NSString *tsName = [MCSFileManager hls_tsNameForTsProxyURL:proxyURL];
        NSString *filename = [MCSFileManager hls_createContentFileInResource:self.name tsName:tsName tsTotalLength:totalLength];
        MCSResourcePartialContent *content = [MCSResourcePartialContent.alloc initWithName:filename tsName:tsName tsTotalLength:totalLength length:0];
        [self addContent:content];
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

@synthesize tsContentType = _tsContentType;
- (NSString *)tsContentType {
    [self lock];
    @try {
        return _tsContentType;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)updateTsContentType:(NSString * _Nullable)tsContentType {
    [self lock];
    _tsContentType = tsContentType;
    [self unlock];
    [MCSResourceManager.shared saveMetadata:self];
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
