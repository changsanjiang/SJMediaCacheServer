//
//  MCSHLSResource.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSResource.h"
#import "MCSResourceManager.h"
#import "MCSHLSReader.h"
#import "MCSHLSParser.h"
#import "MCSFileManager.h"
#import "MCSQueue.h"

@interface MCSHLSResource ()
@property (nonatomic) NSUInteger TsCount;
@end

@implementation MCSHLSResource

- (MCSResourceType)type {
    return MCSResourceTypeHLS;
}

- (id<MCSResourceReader>)readerWithRequest:(NSURLRequest *)request {
    return [MCSHLSReader.alloc initWithResource:self request:request];
}
 
- (NSURL *)playbackURLForCacheWithURL:(NSURL *)URL {
    return [MCSURLRecognizer.shared proxyURLWithURL:URL];
}

- (void)prepareForReader {
    dispatch_barrier_sync(MCSResourceQueue(), ^{
        _parser = [MCSHLSParser parserInResourceIfExists:_name];
        _TsCount = _parser.TsCount;
    });
    [self addContents:[MCSFileManager getContentsInResource:_name]];
}

@synthesize parser = _parser;
- (void)setParser:(MCSHLSParser *)parser {
    dispatch_barrier_sync(MCSResourceQueue(), ^{
        _parser = parser;
        _TsCount = parser.TsCount;
    });
    [MCSResourceManager.shared saveMetadata:self];
}

- (MCSHLSParser *)parser {
    __block MCSHLSParser *parser = nil;
    dispatch_sync(MCSResourceQueue(), ^{
        parser = _parser;
    });
    return parser;
}

@synthesize TsContentType = _TsContentType;
- (NSString *)TsContentType {
    __block NSString *TsContentType = nil;
    dispatch_sync(MCSResourceQueue(), ^{
        TsContentType = _TsContentType;
    });
    return TsContentType;
}

- (void)readWriteCountDidChangeForPartialContent:(MCSResourcePartialContent *)content {
    if ( content.readWriteCount > 0 )
        return;
    
    dispatch_barrier_sync(MCSResourceQueue(), ^{
        if ( _isCacheFinished )
            return;
        
        if ( _m.count < 2 )
            return;
         
        NSMutableArray<MCSHLSPartialContent *> *contents = NSMutableArray.alloc.init;
        for ( MCSHLSPartialContent *c in _m ) {
            if ( c.readWriteCount == 0 ) {
                [contents addObject:c];
            }
        }
        
        NSMutableArray<MCSResourcePartialContent *> *deleteList = NSMutableArray.alloc.init;
   
        if ( contents.count > 1 ) {
            [contents sortUsingComparator:^NSComparisonResult(MCSHLSPartialContent *_Nonnull obj1, MCSHLSPartialContent *_Nonnull obj2) {
                if ( [obj1.name isEqualToString:obj2.name] ) {
                    return obj1.length > obj2.length ? NSOrderedAscending : NSOrderedDescending;
                }
                return [obj1.name compare:obj2.name];
            }];
            
            for ( NSInteger i = 0 ; i < contents.count ; ++ i ) {
                MCSHLSPartialContent *obj1 = contents[i];
                if ( obj1.length == obj1.totalLength ) {
                    for ( NSInteger j = i + 1 ; j < contents.count ; ++ j ) {
                        MCSHLSPartialContent *obj2 = contents[j];
                        if ( [obj1.name isEqualToString:obj2.name] ) {
                            [deleteList addObject:obj2];
                            ++ i;
                        }
                        else {
                            break;
                        }
                    }
                }
            }
        }
        
        if ( deleteList.count == 0 )
            return;
         
        [self removeContents:deleteList];
    });
}
 
#pragma mark -

- (nullable __kindof MCSResourcePartialContent *)contentForProxyURL:(NSURL *)proxyURL {
    MCSDataType dataType = [MCSURLRecognizer.shared dataTypeForProxyURL:proxyURL];
    NSString *extension = nil;
    switch ( dataType ) {
        case MCSDataTypeHLSAESKey:
            extension = MCSHLSAESKeyFileExtension;
            break;
        case MCSDataTypeHLSTs:
            extension = MCSHLSTsFileExtension;
            break;
        default: break;
    }

    if ( extension == nil )
        return nil;
    
    NSString *name = [MCSURLRecognizer.shared nameWithUrl:proxyURL.absoluteString extension:extension];
    for ( MCSHLSPartialContent *c in self.contents ) {
        if ( c.type == dataType && [c.name isEqualToString:name] && c.length == c.totalLength) {
            return c;
        }
    }
    return nil;
}

- (nullable MCSResourcePartialContent *)createContentWithProxyURL:(NSURL *)proxyURL response:(NSHTTPURLResponse *)response {
    MCSDataType dataType = [MCSURLRecognizer.shared dataTypeForProxyURL:proxyURL];
    MCSHLSPartialContent *_Nullable content = nil;
    NSUInteger totalLength = (NSUInteger)response.expectedContentLength;
    NSAssert(totalLength != 0, @"The content totalLength must be greater than 0!");
    
    switch ( dataType ) {
        case MCSDataTypeHLSAESKey: {
            NSString *AESKeyName = [MCSURLRecognizer.shared nameWithUrl:proxyURL.absoluteString extension:MCSHLSAESKeyFileExtension];
            NSString *filename = [MCSFileManager hls_createAESKeyFileInResource:_name AESKeyName:AESKeyName totalLength:totalLength];
            content = [MCSHLSPartialContent AESKeyPartialContentWithFilename:filename name:AESKeyName totalLength:totalLength length:0];
        }
            break;
        case MCSDataTypeHLSTs: {
            NSString *TsName = [MCSURLRecognizer.shared nameWithUrl:proxyURL.absoluteString extension:MCSHLSTsFileExtension];
            NSString *filename = [MCSFileManager hls_createTsFileInResource:_name tsName:TsName tsTotalLength:totalLength];
            content = [MCSHLSPartialContent TsPartialContentWithFilename:filename name:TsName totalLength:totalLength length:0];
        }
            break;
        default:
            assert("Invalid data type!");
            break;
    }
    if ( content != nil ) {
        [self addContent:content];
    }
    return content;
}

#pragma mark -

- (void)updateTsContentType:(NSString * _Nullable)TsContentType {
    dispatch_barrier_sync(MCSResourceQueue(), ^{
        _TsContentType = TsContentType;
        [MCSResourceManager.shared saveMetadata:self];
    });
}

- (nullable MCSResourcePartialContent *)contentForTsURL:(NSURL *)URL {
    __block MCSResourcePartialContent *content = nil;
    NSString *TsName = [MCSURLRecognizer.shared nameWithUrl:URL.absoluteString extension:MCSHLSTsFileExtension];
    dispatch_barrier_sync(MCSResourceQueue(), ^{
        for ( MCSResourcePartialContent *c in _m ) {
            if ( [c.tsName isEqualToString:TsName] ) {
                NSString *contentPath = [MCSFileManager getFilePathWithName:c.filename inResource:self.name];
                NSUInteger length = [MCSFileManager fileSizeAtPath:contentPath];
                if ( length == c.tsTotalLength ) {
                    content = c;
                    break;
                }
            }
        }
    });
    return content;
}

- (MCSResourcePartialContent *)createContentWithTsURL:(NSURL *)URL totalLength:(NSUInteger)totalLength {
    MCSResourcePartialContent *content = nil;
    NSString *TsName = [MCSURLRecognizer.shared nameWithUrl:URL.absoluteString extension:MCSHLSTsFileExtension];
    NSString *filename = [MCSFileManager hls_createTsFileInResource:self.name tsName:TsName tsTotalLength:totalLength];
    content = [MCSResourcePartialContent.alloc initWithFilename:filename tsName:TsName tsTotalLength:totalLength length:0];
    [self addContent:content];
    return content;
}

- (void)contentsDidChange:(NSArray<__kindof MCSResourcePartialContent *> *)contents {
    BOOL isContentsFinished = YES;
    NSUInteger count = 0;
    for ( __kindof MCSResourcePartialContent *c in contents ) {
        if ( c.type == MCSDataTypeHLSTs ) {
            MCSHLSPartialContent *content = c;
            if ( content.length != content.totalLength ) {
                isContentsFinished = NO;
                break;
            }
            count += 1;
        }
    }
    
    _isCacheFinished = isContentsFinished && count == _TsCount;
}
@end
