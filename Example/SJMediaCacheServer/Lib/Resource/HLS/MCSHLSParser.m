//
//  MCSHLSParser.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSParser.h"
#import "MCSError.h"

@interface NSString (SJM3U8FileParserExtended)
- (nullable NSArray<NSValue *> *)sj_rangesByMatchingPattern:(NSString *)pattern;
- (nullable NSString *)sj_filename;
@end

@interface MCSHLSParser ()<NSLocking> {
    NSRecursiveLock *_lock;
}
@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic, strong, nullable) NSURL *URL;
@property (nonatomic, weak, nullable) id<MCSHLSParserDelegate> delegate;
@end

@implementation MCSHLSParser
- (instancetype)initWithURL:(NSURL *)URL delegate:(id<MCSHLSParserDelegate>)delegate {
    self = [super init];
    if ( self ) {
        _URL = URL;
        _delegate = delegate;
        _lock = NSRecursiveLock.alloc.init;
    }
    return self;
}

- (void)prepare {
    [self lock];
    @try {
        if ( _isClosed || _isCalledPrepare )
            return;
        
        _isCalledPrepare = YES;
        [self _parse];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (void)close {
    
}

#pragma mark -

- (void)_parse {
    NSString *_Nullable source = nil;
    NSString *_Nullable redirect = nil;
    NSArray<NSString *> *_Nullable tsArray = nil;
    NSError *_Nullable error = nil;
    NSString *url = _URL.absoluteString;
    do {
        NSURL *URL = [NSURL URLWithString:url];
        source = [NSString stringWithContentsOfURL:URL encoding:0 error:&error];
        if ( source == nil )
            break;

        // 是否重定向
        redirect = [self _urlsWithPattern:@"(?:.*\\.m3u8[^\\s]*)" url:url resource:source].firstObject;

        if ( redirect == nil ) {
            // 解析ts地址
            tsArray = [self _urlsWithPattern:@"(?:.*\\.ts[^\\s]*)" url:url resource:source];
            break;
        }

        url = redirect;
        
    } while (true);

    if ( error != nil || tsArray == nil ) {
        [_delegate parser:self anErrorOccurred:error ?: [NSError mcs_errorForHLSFileParseError:_URL]];
        return;
    }

    [self _restructureContents:source saveKeyToFolder:nil error:NULL];
    
    NSString *restructureContents = [self _restructureContents:source saveKeyToFolder:nil error:NULL];
    if ( restructureContents.length == 0 ) {
        [_delegate parser:self anErrorOccurred:error ?: [NSError mcs_errorForHLSFileParseError:_URL]];
        return;
    }

//    MCSHLSM3u8Resource *parser = MCSHLSM3u8Resource.alloc.init;
//    parser.url = url;
//    parser.tsArray = tsArray;
//    parser.contents = restructureContents;
//    return parser;
}

//+ (nullable instancetype)fileParserWithContentsOfFile:(NSString *)path error:(NSError **)error {
//    if ( path.length == 0 )
//        return nil;
//
//    NSError *inner_error = nil;
//    NSDictionary *info = nil;
//    if (@available(iOS 11.0, *)) {
//        info = [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:path] error:&inner_error];
//    } else {
//        info = [NSDictionary dictionaryWithContentsOfFile:path];
//        if ( info == nil ) inner_error = SJM3U8FileParseError;
//    }
//
//    if ( inner_error != nil ) {
//        if ( error != NULL )  *error = inner_error;
//        return nil;
//    }
//    MCSHLSM3u8Resource *fileParser = MCSHLSM3u8Resource.alloc.init;
//    fileParser.url = info[@"url"];
//    fileParser.tsArray = info[@"tsArray"];
//    fileParser.contents = info[@"contents"];
//    return fileParser;
//}

- (nullable NSArray<NSString *> *)_urlsWithPattern:(NSString *)pattern url:(NSString *)url resource:(NSString *)contents {
    NSMutableArray<NSString *> *m = NSMutableArray.array;
    [[contents sj_rangesByMatchingPattern:pattern] enumerateObjectsUsingBlock:^(NSValue * _Nonnull range, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *matched = [contents substringWithRange:[range rangeValue]];
        NSString *matchedUrl = [self _urlWithMatchedString:matched];
        [m addObject:matchedUrl];
    }];

    return m.count != 0 ? m.copy : nil;
}

- (NSString *)_urlWithMatchedString:(NSString *)matched {
    NSString *url = nil;
    if ( [matched containsString:@"://"] ) {
        url = matched;
    }
    else if ( [matched hasPrefix:@"/"] ) {
        url = [NSString stringWithFormat:@"%@://%@%@", _URL.scheme, _URL.host, matched];
    }
    else {
        url = [NSString stringWithFormat:@"%@/%@", _URL.absoluteString.stringByDeletingLastPathComponent, matched];
    }
    return url;
}

- (void)_generateIndexFileForSource:(NSString *)source {
    NSMutableString *m = source.mutableCopy;
    [[source sj_rangesByMatchingPattern:@"(?:.*\\.ts[^\\s]*)"] enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSValue * _Nonnull range, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange rangeValue = range.rangeValue;
        NSString *matched = [source substringWithRange:rangeValue];
        NSString *url = [self _urlWithMatchedString:matched];
        NSString *filename = [self.delegate parser:self tsFilenameForUrl:url];
        if ( filename != nil ) [m replaceCharactersInRange:rangeValue withString:filename];
    }];

    
#warning next ..... mmm
    
    __block NSError *inner_error = nil;
    ///
    /// #EXT-X-KEY:METHOD=AES-128,URI="...",IV=...
    ///
    [[m sj_rangesByMatchingPattern:@"#EXT-X-KEY:METHOD=AES-128,URI=\".*\""] enumerateObjectsUsingBlock:^(NSValue * _Nonnull range, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange rangeValue = range.rangeValue;
        NSString *matched = [contents substringWithRange:rangeValue];
        NSInteger URILocation = [matched rangeOfString:@"\""].location + 1;
        NSRange URIRange = NSMakeRange(URILocation, matched.length-URILocation-1);
        NSString *URI = [matched substringWithRange:URIRange];
        NSData *keyData = [NSData dataWithContentsOfURL:[NSURL URLWithString:URI] options:0 error:&inner_error];
        if ( inner_error != nil ) {
            *stop = YES;
            return ;
        }
        [keyData writeToFile:[folder stringByAppendingPathComponent:URI.sj_filename] options:0 error:&inner_error];
        if ( inner_error != nil ) {
            *stop = YES;
            return ;
        }
        NSString *reset = [matched stringByReplacingCharactersInRange:URIRange withString:URI.sj_filename];
        [m replaceCharactersInRange:rangeValue withString:reset];
    }];

    if ( inner_error != nil ) {
        if ( error != NULL ) *error = inner_error;
        return nil;
    }
}

- (nullable NSString *)_restructureContents:(NSString *)contents saveKeyToFolder:(NSString *)folder error:(NSError **)error {
    NSMutableString *m = contents.mutableCopy;
    [[contents sj_rangesByMatchingPattern:@"(?:.*\\.ts[^\\s]*)"] enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSValue * _Nonnull range, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange rangeValue = range.rangeValue;
        NSString *matched = [contents substringWithRange:rangeValue];
        NSString *filename = matched.sj_filename;
        [m replaceCharactersInRange:rangeValue withString:filename];
    }];

    __block NSError *inner_error = nil;
    ///
    /// #EXT-X-KEY:METHOD=AES-128,URI="...",IV=...
    ///
    [[m sj_rangesByMatchingPattern:@"#EXT-X-KEY:METHOD=AES-128,URI=\".*\""] enumerateObjectsUsingBlock:^(NSValue * _Nonnull range, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange rangeValue = range.rangeValue;
        NSString *matched = [contents substringWithRange:rangeValue];
        NSInteger URILocation = [matched rangeOfString:@"\""].location + 1;
        NSRange URIRange = NSMakeRange(URILocation, matched.length-URILocation-1);
        NSString *URI = [matched substringWithRange:URIRange];
        NSData *keyData = [NSData dataWithContentsOfURL:[NSURL URLWithString:URI] options:0 error:&inner_error];
        if ( inner_error != nil ) {
            *stop = YES;
            return ;
        }
        [keyData writeToFile:[folder stringByAppendingPathComponent:URI.sj_filename] options:0 error:&inner_error];
        if ( inner_error != nil ) {
            *stop = YES;
            return ;
        }
        NSString *reset = [matched stringByReplacingCharactersInRange:URIRange withString:URI.sj_filename];
        [m replaceCharactersInRange:rangeValue withString:reset];
    }];

    if ( inner_error != nil ) {
        if ( error != NULL ) *error = inner_error;
        return nil;
    }
    return m.copy;
}

- (void)writeToFile:(NSString *)path error:(NSError **)error {
    if ( path.length != 0 ) {
        NSMutableDictionary *info = NSMutableDictionary.dictionary;
        info[@"url"] = self.url;
        info[@"tsArray"] = self.tsArray;
        info[@"contents"] = self.contents;
        if (@available(iOS 11.0, *)) {
            [info writeToURL:[NSURL fileURLWithPath:path] error:error];
        } else {
            [info writeToFile:path atomically:NO];
        }
    }
}

- (void)writeContentsToFile:(NSString *)path error:(NSError **)error {
    if ( path.length != 0 ) {
        [self.contents writeToURL:[NSURL fileURLWithPath:path] atomically:NO encoding:NSUTF8StringEncoding error:error];
    }
}

- (nullable NSString *)tsfilenameAtIndex:(NSInteger)idx {
    if ( idx < self.tsArray.count && idx >= 0 ) {
        return self.tsArray[idx].sj_filename;
    }
    return nil;
}
@end




@implementation NSString (SJM3U8FileParserExtended)
- (nullable NSArray<NSValue *> *)sj_rangesByMatchingPattern:(NSString *)pattern {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:kNilOptions error:NULL];
    NSMutableArray<NSValue *> *m = NSMutableArray.array;
    [regex enumerateMatchesInString:self options:NSMatchingWithoutAnchoringBounds range:NSMakeRange(0, self.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        if ( result != nil ) {
            [m addObject:[NSValue valueWithRange:result.range]];
        }
    }];
    return m.count != 0 ? m.copy : nil;
}

- (nullable NSString *)sj_filename {
    NSString *component = self.lastPathComponent;
    NSRange range = [component rangeOfString:@"?"];
    if ( range.location != NSNotFound ) {
        return [component substringToIndex:range.location];
    }
    return component;
}


#pragma mark -

- (void)lock {
    [_lock lock];
}

- (void)unlock {
    [_lock unlock];
}
@end
