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
    _parser = [MCSHLSParser parserInResourceIfExists:_name];
    [self _addContents:[MCSFileManager getContentsInResource:_name]];
}

- (void)parseDidFinish:(MCSHLSParser *)parser {
    self.parser = parser;
}

@synthesize parser = _parser;
- (void)setParser:(MCSHLSParser *)parser {
    dispatch_barrier_sync(MCSResourceQueue(), ^{
        _parser = parser;
    });
}

- (MCSHLSParser *)parser {
    __block MCSHLSParser *parser = nil;
    dispatch_sync(MCSResourceQueue(), ^{
        parser = _parser;
    });
    return parser;
}
 
#pragma mark -

- (nullable __kindof MCSResourcePartialContent *)partialContentForFileDataReaderWithProxyURL:(NSURL *)proxyURL {
    MCSDataType dataType = [MCSURLRecognizer.shared dataTypeForProxyURL:proxyURL];
    NSString *extension = nil;
    switch ( dataType ) {
        case MCSDataTypeHLSAESKey:
            extension = MCSHLSAESKeyFileExtension;
            break;
        case MCSDataTypeHLSTs:
            extension = MCSHLSTsFileExtension;
            break;
        default:
            assert("Invalid data type!");
            break;
    }

    if ( extension == nil )
        return nil;
    
    __block MCSHLSPartialContent *content = nil;
    dispatch_barrier_sync(MCSResourceQueue(), ^{
        NSString *name = [MCSURLRecognizer.shared nameWithUrl:proxyURL.absoluteString extension:extension];
        for ( MCSHLSPartialContent *c in _m.copy ) {
            if ( c.type == dataType && [c.name isEqualToString:name] && c.length == c.totalLength) {
                content = c;
                break;
            }
        }
    });
    return content;
}

/// 创建一个content
///
///     注意: 请在读写结束后调用 [resource didEndReadwriteContent:content];
///
- (nullable MCSResourcePartialContent *)partialContentForNetworkDataReaderWithProxyURL:(NSURL *)proxyURL response:(NSHTTPURLResponse *)response {
    __block MCSHLSPartialContent *_Nullable content = nil;
    dispatch_barrier_sync(MCSResourceQueue(), ^{
        MCSDataType dataType = [MCSURLRecognizer.shared dataTypeForProxyURL:proxyURL];
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
            [content readwriteRetain];
            [self _addContent:content];
        }
    });
    return content;
}

- (void)willReadwriteContent:(MCSResourcePartialContent *)content {
    dispatch_barrier_sync(MCSResourceQueue(), ^{
        [content readwriteRetain];
    });
}

- (void)didEndReadwriteContent:(MCSResourcePartialContent *)content {
    dispatch_barrier_sync(MCSResourceQueue(), ^{
        if ( _isCacheFinished )
            return;
        
        if ( _m.count < 2 )
            return;
        
        NSMutableArray<MCSHLSPartialContent *> *contents = NSMutableArray.alloc.init;
        for ( MCSHLSPartialContent *c in _m.copy ) {
            if ( c.readwriteCount == 0 ) {
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
        
        [self _removeContents:deleteList];
    });
}

- (void)_contentsDidChange:(NSArray<__kindof MCSResourcePartialContent *> *)contents {
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
    
    _isCacheFinished = isContentsFinished && count == _parser.TsCount;
}
@end
