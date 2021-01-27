//
//  HLSParser.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "HLSParser.h"
#import "MCSError.h"
#import "MCSData.h"
#import "MCSURLRecognizer.h"
#import "NSURLRequest+MCS.h"
#import "MCSQueue.h"
#import "HLSAsset.h"

// https://tools.ietf.org/html/rfc8216

#define HLS_FORMAT_FIRST_LINE_TAG           @"#EXTM3U"
     
#define HLS_REGEX_INDEX                     @".*\\.m3u8[^\\s]*"
#define HLS_REGEX_INDEX_2                   @"#EXT-X-STREAM-INF.+\\s(.+)\\s"
#define HLS_REGEX_TS                        @"#EXTINF.+\\s(.+)\\s"
#define HLS_REGEX_AESKEY                    @"#EXT-X-KEY:METHOD=AES-128,URI=\"(.*)\""
#define HLS_REGEX_LOCAL_URIs                @"(.*\\.ts[^\\s]*)|(#EXT-X-KEY:METHOD=AES-128,URI=\"(.*)\")"

#define HLS_INDEX_TS        1
#define HLS_INDEX_AESKEY    1
#define HLS_INDEX_INDEX_2   1

static dispatch_queue_t mcs_queue;

@interface NSString (MCSRegexMatching)
- (nullable NSArray<NSValue *> *)mcs_rangesByMatchingPattern:(NSString *)pattern;
- (nullable NSArray<NSTextCheckingResult *> *)mcs_textCheckingResultsByMatchPattern:(NSString *)pattern;
@end

@interface NSString (MCSHLSContents)
- (nullable NSArray<NSString *> *)mcs_urlsByMatchingPattern:(NSString *)pattern contentsURL:(NSURL *)contentsURL;
- (nullable NSArray<NSString *> *)mcs_urlsByMatchingPattern:(NSString *)pattern atIndex:(NSInteger)index contentsURL:(NSURL *)contentsURL;
- (NSString *)mcs_convertToUrlByContentsURL:(NSURL *)contentsURL;
@end

@interface HLSParser ()
@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, weak, nullable) id<HLSParserDelegate> delegate;
@property (nonatomic, strong) NSArray<NSString *> *TsURIArray;
@property (nonatomic) float networkTaskPriority;
@property (nonatomic, strong) NSArray<NSString *> *URIs;
@end

@implementation HLSParser
+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mcs_queue = dispatch_queue_create("queue.HLSParser", DISPATCH_QUEUE_CONCURRENT);
    });
}

+ (nullable instancetype)parserInAsset:(HLSAsset *)asset {
    NSParameterAssert(asset);
    NSString *filePath = [asset indexFilePath];
    // 已解析过, 将直接读取本地
    if ( [NSFileManager.defaultManager fileExistsAtPath:filePath] ) {
        HLSParser *parser = HLSParser.alloc.init;
        parser->_asset = asset;
        [parser _finished];
        return parser;
    }
    return nil;
}

- (instancetype)initWithAsset:(HLSAsset *)asset request:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority delegate:(id<HLSParserDelegate>)delegate {
    self = [self init];
    if ( self ) {
        NSParameterAssert(asset);
        _asset = asset;
        _networkTaskPriority = networkTaskPriority;
        _request = request;
        _delegate = delegate;
    }
    return self;
}

- (nullable NSString *)URIAtIndex:(NSUInteger)index {
    __block NSString *URI = nil;
    dispatch_sync(mcs_queue, ^{
        URI = index < _URIs.count ? _URIs[index] : nil;
    });
    return URI;
}

- (void)prepare {
    dispatch_barrier_async(mcs_queue, ^{
        if ( self->_isClosed || self->_isCalledPrepare )
            return;
        
        self->_isCalledPrepare = YES;
        
        @autoreleasepool {
            [self _parse];
        }
    });
}

- (void)close {
    dispatch_barrier_sync(mcs_queue, ^{
        [self _close];
    });
}

@synthesize isDone = _isDone;
- (BOOL)isDone {
    __block BOOL isDone = NO;
    dispatch_sync(mcs_queue, ^{
        isDone = _isDone;
    });
    return isDone;
}

@synthesize isClosed = _isClosed;
- (BOOL)isClosed {
    __block BOOL isClosed = NO;
    dispatch_sync(mcs_queue, ^{
        isClosed = _isClosed;
    });
    return isClosed;
}

- (NSUInteger)TsCount {
    __block NSUInteger count = 0;
    dispatch_sync(mcs_queue, ^{
        count = _TsURIArray.count;
    });
    return count;
}

#pragma mark -

- (void)_parse {
    
    NSString *indexFilePath = [_asset indexFilePath];
    // 已解析过, 将直接读取本地
    if ( [NSFileManager.defaultManager fileExistsAtPath:indexFilePath] ) {
        [self _finished];
        return;
    }
    
    HLSAsset *asset = _asset;
    
    if ( asset == nil ) {
        [self _close];
        return;
    }
    
    __block NSURLRequest *currRequest = _request;
    NSString *_Nullable contents = nil;
    do {
        NSError *downloadError = nil;
        NSData *data = [MCSData dataWithContentsOfRequest:currRequest networkTaskPriority:_networkTaskPriority error:&downloadError willPerformHTTPRedirection:^(NSHTTPURLResponse * _Nonnull response, NSURLRequest * _Nonnull newRequest) {
            currRequest = newRequest;
        }];
        if ( downloadError != nil ) {
            [self _onError:[NSError mcs_errorWithCode:MCSUnknownError userInfo:@{
                MCSErrorUserInfoObjectKey : currRequest,
                MCSErrorUserInfoErrorKey : downloadError,
                MCSErrorUserInfoReasonKey : @"下载数据失败!"
            }]];
            return;
        }
        
        contents = [NSString.alloc initWithData:data encoding:0];
        if ( contents == nil )
            break;
        
        // 是否重定向
        NSString *next = [self _indexUrlForContents:contents contentsURL:currRequest.URL];
        if ( next == nil ) break;
        
        currRequest = [currRequest mcs_requestWithRedirectURL:[NSURL URLWithString:next]];
    } while ( true );
    
    if ( contents == nil || ![contents hasPrefix:HLS_FORMAT_FIRST_LINE_TAG] ) {
        [self _onError:[NSError mcs_errorWithCode:MCSFileError userInfo:@{
            MCSErrorUserInfoObjectKey : contents ?: @"",
            MCSErrorUserInfoReasonKey : @"数据为空或格式不正确!"
        }]];
        return;
    }
 
    NSMutableString *indexFileContents = contents.mutableCopy;
    ///
    /// #EXTINF:10,
    /// 000000.ts
    ///
    NSArray<NSTextCheckingResult *> *TsResults =[contents mcs_textCheckingResultsByMatchPattern:HLS_REGEX_TS];
    if ( TsResults.count == 0 ) {
        [self _onError:[NSError mcs_errorWithCode:MCSFileError userInfo:@{
            MCSErrorUserInfoObjectKey : contents,
            MCSErrorUserInfoReasonKey : @"数据格式不正确, 未匹配到ts文件!"
        }]];
        return;
    }
    [TsResults enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull result, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange range = [result rangeAtIndex:HLS_INDEX_TS];
        NSString *matched = [contents substringWithRange:range];
        NSString *url = [matched mcs_convertToUrlByContentsURL:currRequest.URL];
        NSString *proxy = [MCSURLRecognizer.shared proxyTsURIWithUrl:url inAsset:asset.name];
        [indexFileContents replaceCharactersInRange:range withString:proxy];
    }];
 
    ///
    /// #EXT-X-KEY:METHOD=AES-128,URI="...",IV=...
    ///
    [[indexFileContents mcs_textCheckingResultsByMatchPattern:HLS_REGEX_AESKEY] enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull result, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange URIRange = [result rangeAtIndex:HLS_INDEX_AESKEY];
        NSString *URI = [indexFileContents substringWithRange:URIRange];
        NSString *url = [URI mcs_convertToUrlByContentsURL:currRequest.URL];
        NSString *proxy = [MCSURLRecognizer.shared proxyAESKeyURIWithUrl:url inAsset:asset.name];
        [indexFileContents replaceCharactersInRange:URIRange withString:proxy];
    }];
    
    [_asset lock:^{
        if ( ![NSFileManager.defaultManager fileExistsAtPath:indexFilePath] ) {
            NSError *_Nullable error = nil;
            if ( ![indexFileContents writeToFile:indexFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error] ) {
                [self _onError:error];
                return;
            }
        }
    }];
    
    [self _finished];
}

- (nullable NSString *)_indexUrlForContents:(NSString *)contents contentsURL:(NSURL *)contentsURL {
    // 是否重定向
    // 1
    NSString *redirectUrl = [contents mcs_urlsByMatchingPattern:HLS_REGEX_INDEX contentsURL:contentsURL].firstObject;
    // 2
    if ( redirectUrl == nil ) {
        redirectUrl = [contents mcs_urlsByMatchingPattern:HLS_REGEX_INDEX_2 atIndex:HLS_INDEX_INDEX_2 contentsURL:contentsURL].firstObject;
    }
    return redirectUrl;
}

- (void)_onError:(NSError *)error {
#ifdef DEBUG
    NSLog(@"%d - %s - %@", (int)__LINE__, __func__, error);
#endif
    [self _close];
    
    dispatch_async(MCSDelegateQueue(), ^{
        [self->_delegate parser:self anErrorOccurred:error];
    });
}

- (void)_finished {
    if ( _isClosed )
        return;
    
    NSString *indexFilePath = [_asset indexFilePath];
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfFile:indexFilePath encoding:NSUTF8StringEncoding error:&error];
    if ( content == nil ) {
        [self _onError:error];
        return;
    }
    
    NSMutableArray<NSString *> *TsURIArray = NSMutableArray.array;
    NSMutableArray<NSString *> *URIs = NSMutableArray.array;
    [[content mcs_textCheckingResultsByMatchPattern:HLS_REGEX_LOCAL_URIs] enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange range1 = [obj rangeAtIndex:1];
        NSRange range3 = [obj rangeAtIndex:3];
        if      ( range1.location != NSNotFound ) {
            NSString *TsURI = [content substringWithRange:range1];
            [TsURIArray addObject:TsURI];
            [URIs addObject:TsURI];
        }
        else if ( range3.location != NSNotFound ) {
            NSString *AESKeyURI = [content substringWithRange:range3];
            [URIs addObject:AESKeyURI];
        }
    }];
    
    _TsURIArray = TsURIArray.copy;
    _URIs = URIs.copy;
    
    _isDone = YES;
    
    dispatch_async(MCSDelegateQueue(), ^{
        [self->_delegate parserParseDidFinish:self];
    });
}

- (void)_close {
    if ( _isClosed ) return;
    _isClosed = YES;
}
@end

@implementation NSString (MCSRegexMatching)
- (nullable NSArray<NSValue *> *)mcs_rangesByMatchingPattern:(NSString *)pattern {
    NSMutableArray<NSValue *> *m = NSMutableArray.array;
    for ( NSTextCheckingResult *result in [self mcs_textCheckingResultsByMatchPattern:pattern])
        [m addObject:[NSValue valueWithRange:result.range]];
    return m.count != 0 ? m.copy : nil;
}

- (nullable NSArray<NSTextCheckingResult *> *)mcs_textCheckingResultsByMatchPattern:(NSString *)pattern {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:kNilOptions error:NULL];
    NSMutableArray<NSTextCheckingResult *> *m = NSMutableArray.array;
    [regex enumerateMatchesInString:self options:kNilOptions range:NSMakeRange(0, self.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        if ( result != nil ) {
            [m addObject:result];
        }
    }];
    return m.count != 0 ? m.copy : nil;
}
@end

@implementation NSString (MCSHLSContents)
- (nullable NSArray<NSString *> *)mcs_urlsByMatchingPattern:(NSString *)pattern contentsURL:(NSURL *)contentsURL {
    return [self mcs_urlsByMatchingPattern:pattern atIndex:0 contentsURL:contentsURL];
}

- (nullable NSArray<NSString *> *)mcs_urlsByMatchingPattern:(NSString *)pattern atIndex:(NSInteger)index contentsURL:(NSURL *)contentsURL {
    NSMutableArray<NSString *> *m = NSMutableArray.array;
    [[self mcs_textCheckingResultsByMatchPattern:pattern] enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
//        The range at index 0 always matches the range property.  Additional ranges, if any, will have indexes from 1 to numberOfRanges-1. rangeWithName: can be used with named regular expression capture groups
        NSRange range = [obj rangeAtIndex:index];
        NSString *matched = [self substringWithRange:range];
        NSString *url = [matched mcs_convertToUrlByContentsURL:contentsURL];
        [m addObject:url];
    }];
    return m.count != 0 ? m.copy : nil;
}

/// 将路径转换为url
- (NSString *)mcs_convertToUrlByContentsURL:(NSURL *)URL {
    static NSString *const HLS_PREFIX_LOCALHOST = @"http://localhost";
    static NSString *const HLS_PREFIX_PATH = @"/";
    
    NSString *url = nil;
    if ( [self hasPrefix:HLS_PREFIX_PATH] ) {
        url = [NSString stringWithFormat:@"%@://%@%@", URL.scheme, URL.host, self];
    }
    else if ( [self hasPrefix:HLS_PREFIX_LOCALHOST] ) {
        url = [NSString stringWithFormat:@"%@://%@%@", URL.scheme, URL.host, [self substringFromIndex:HLS_PREFIX_LOCALHOST.length]];
    }
    else if ( [self containsString:@"://"] ) {
        url = self;
    }
    else {
        url = [NSString stringWithFormat:@"%@/%@", URL.absoluteString.stringByDeletingLastPathComponent, self];
    }
    return url;
}
@end
