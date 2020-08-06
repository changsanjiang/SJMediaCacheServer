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
        
        NSMutableArray<MCSHLSIndexPartialContent *> *indexArray = NSMutableArray.alloc.init;
        NSMutableArray<MCSHLSAESKeyPartialContent *> *AESKeyArray = NSMutableArray.alloc.init;
        NSMutableArray<MCSHLSTsPartialContent *> *TsArray = NSMutableArray.alloc.init;
        
        for ( __kindof MCSResourcePartialContent *content in _m ) {
            if ( content.readWriteCount == 0 ) {
                if      ( content.type == MCSDataTypeHLSPlaylist ) [indexArray addObject:content];
                else if ( content.type == MCSDataTypeHLSAESKey ) [AESKeyArray addObject:content];
                else if ( content.type == MCSDataTypeHLSTs ) [TsArray addObject:content];
            }
        }
        
        NSMutableArray<MCSResourcePartialContent *> *deleteArray = NSMutableArray.alloc.init;
        if ( indexArray.count > 1 ) {
            [indexArray sortUsingComparator:^NSComparisonResult(MCSHLSIndexPartialContent  *_Nonnull obj1, MCSHLSIndexPartialContent *_Nonnull obj2) {
                return obj1.length > obj2.length ? NSOrderedAscending : NSOrderedDescending;
            }];

            MCSHLSIndexPartialContent *index = indexArray.firstObject;
            if ( index.length == index.totalLength ) {
                [deleteArray addObjectsFromArray:[indexArray subarrayWithRange:NSMakeRange(1, indexArray.count - 1)]];
            }
        }

        if ( AESKeyArray.count > 1 ) {
            [AESKeyArray sortUsingComparator:^NSComparisonResult(MCSHLSAESKeyPartialContent *_Nonnull obj1, MCSHLSAESKeyPartialContent *_Nonnull obj2) {
                if ( [obj1.AESKeyName isEqualToString:obj2.AESKeyName] ) {
                    return obj1.length > obj2.length ? NSOrderedAscending : NSOrderedDescending;
                }
                return NSOrderedSame;
            }];
            
            for ( NSInteger i = 0 ; i < AESKeyArray.count ; ++ i ) {
                MCSHLSAESKeyPartialContent *obj1 = AESKeyArray[i];
                if ( obj1.length == obj1.totalLength ) {
                    for ( NSInteger j = i + 1 ; j < AESKeyArray.count ; ++ j ) {
                        MCSHLSAESKeyPartialContent *obj2 = AESKeyArray[j];
                        if ( [obj1.AESKeyName isEqualToString:obj2.AESKeyName] ) {
                            [deleteArray addObject:obj2];
                            ++ i;
                        }
                    }
                }
            }
        }
        
        if ( TsArray.count > 1 ) {
            [TsArray sortUsingComparator:^NSComparisonResult(MCSHLSTsPartialContent *_Nonnull obj1, MCSHLSTsPartialContent *_Nonnull obj2) {
                if ( [obj1.TsName isEqualToString:obj2.TsName] ) {
                    return obj1.length > obj2.length ? NSOrderedAscending : NSOrderedDescending;
                }
                return NSOrderedSame;
            }];
            
            for ( NSInteger i = 0 ; i < TsArray.count ; ++ i ) {
                MCSHLSTsPartialContent *obj1 = TsArray[i];
                if ( obj1.length == obj1.totalLength ) {
                    for ( NSInteger j = i + 1 ; j < TsArray.count ; ++ j ) {
                        MCSHLSTsPartialContent *obj2 = TsArray[j];
                        if ( [obj1.TsName isEqualToString:obj2.TsName] ) {
                            [deleteArray addObject:obj2];
                            ++ i;
                        }
                    }
                }
            }
        }
        
        if ( deleteArray.count == 0 )
            return;
         
        [self removeContents:deleteArray];
    });
}
 
#pragma mark -

- (nullable MCSResourcePartialContent *)createContentWithRequest:(NSURLRequest *)request response:(NSHTTPURLResponse *)response {
    MCSDataType dataType = [MCSURLRecognizer.shared dataTypeForURL:request.URL];
    MCSResourcePartialContent *_Nullable content = nil;
    NSUInteger totalLength = (NSUInteger)response.expectedContentLength;
    NSAssert(totalLength != 0, @"The content totalLength must be greater than 0!");

    switch ( dataType ) {
        case MCSDataTypeHLSPlaylist: {
            NSString *filename = [MCSFileManager hls_createIndexFileInResource:_name totalLength:totalLength];
            content = [MCSHLSIndexPartialContent.alloc initWithFilename:filename totalLength:totalLength length:0];
        }
            break;
        case MCSDataTypeHLSAESKey: {
            NSString *AESKeyName = [MCSURLRecognizer.shared nameWithUrl:request.URL.absoluteString extension:MCSHLSAESKeyFileExtension];
            NSString *filename = [MCSFileManager hls_createAESKeyFileInResource:_name AESKeyName:AESKeyName totalLength:totalLength];
            content = [MCSHLSAESKeyPartialContent.alloc initWithFilename:filename AESKeyName:AESKeyName totalLength:totalLength length:0];
        }
            break;
        case MCSDataTypeHLSTs: {
            NSString *TsName = [MCSURLRecognizer.shared nameWithUrl:request.URL.absoluteString extension:MCSHLSTsFileExtension];
            NSString *filename = [MCSFileManager hls_createTsFileInResource:_name tsName:TsName tsTotalLength:totalLength];
            content = [MCSHLSTsPartialContent.alloc initWithFilename:filename TsName:TsName totalLength:totalLength length:0];
        }
            break;
        default:
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
            MCSHLSTsPartialContent *content = c;
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
