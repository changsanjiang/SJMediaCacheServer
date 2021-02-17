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
#import "MCSURL.h"
#import "NSURLRequest+MCS.h"
#import "MCSQueue.h"
#import "HLSAsset.h"

// https://tools.ietf.org/html/rfc8216

#define HLS_PREFIX_TAG                  @"#"

#define HLS_PREFIX_FILE_FIRST_LINE      @"#EXTM3U"
#define HLS_PREFIX_TS_DURATION          @"#EXTINF"
#define HLS_PREFIX_TS_BYTERANGE         @"#EXT-X-BYTERANGE"
#define HLS_PREFIX_AESKEY               @"#EXT-X-KEY:METHOD=AES-128"

#define HLS_REGEX_INDEX                 @"^[^#]*\\.m3u8[^\\s]*"
#define HLS_REGEX_INDEX_2               @"#EXT-X-STREAM-INF.+\\s(.+)\\s"
#define HLS_INDEX_INDEX_2   1

#define HLS_REGEX_AESKEY                @"#EXT-X-KEY:METHOD=AES-128,URI=\"(.*)\""
#define HLS_INDEX_AESKEY    1

#define HLS_REGEX_TS_BYTERANGE          @"#EXT-X-BYTERANGE:(.+)@(.+)"
#define HLS_INDEX_TS_BYTERANGE_LOCATION  2
#define HLS_INDEX_TS_BYTERANGE_LENGTH    1

#define HLS_REGEX_LOCAL_URIs            @"(.*\\.ts[^\\s]*)|(#EXT-X-KEY:METHOD=AES-128,URI=\"(.*)\")"

static dispatch_queue_t mcs_queue;

@interface NSString (MCSRegexMatching)
- (nullable NSArray<NSValue *> *)mcs_rangesByMatchingPattern:(NSString *)pattern options:(NSRegularExpressionOptions)options;
- (nullable NSArray<NSTextCheckingResult *> *)mcs_textCheckingResultsByMatchPattern:(NSString *)pattern options:(NSRegularExpressionOptions)options;
@end

@interface MCSHLSURIItem : NSObject
- (instancetype)initWithType:(MCSDataType)type URI:(NSString *)URI HTTPAdditionalHeaders:(nullable NSDictionary *)HTTPAdditionalHeaders;
/// MCSDataTypeHLSAESKey    = 2,
/// MCSDataTypeHLSTs        = 3,
@property (nonatomic, readonly) MCSDataType type;
@property (nonatomic, copy, readonly) NSString *URI;
@property (nonatomic, copy, readonly, nullable) NSDictionary *HTTPAdditionalHeaders;
@end

@implementation MCSHLSURIItem
- (instancetype)initWithType:(MCSDataType)type URI:(NSString *)URI HTTPAdditionalHeaders:(nullable NSDictionary *)HTTPAdditionalHeaders {
    self = [super init];
    if ( self ) {
        _type = type;
        _URI = URI.copy;
        _HTTPAdditionalHeaders = HTTPAdditionalHeaders.copy;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { type: %d, URI: %@, HTTPAdditionalHeaders: %@\n };", NSStringFromClass(self.class), self, _type, _URI, _HTTPAdditionalHeaders];
}
@end

@interface NSString (MCSHLSContents)
- (nullable NSArray<NSString *> *)mcs_urlsByMatchingPattern:(NSString *)pattern contentsURL:(NSURL *)contentsURL options:(NSRegularExpressionOptions)options;
- (nullable NSArray<NSString *> *)mcs_urlsByMatchingPattern:(NSString *)pattern atIndex:(NSInteger)index contentsURL:(NSURL *)contentsURL options:(NSRegularExpressionOptions)options;
- (NSString *)mcs_convertToUrlByContentsURL:(NSURL *)contentsURL;

- (nullable NSArray<NSValue *> *)mcs_TsURIRanges;
- (nullable NSArray<MCSHLSURIItem *> *)mcs_URIItems;
@end

@interface HLSParser ()
@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, weak, nullable) id<HLSParserDelegate> delegate;
@property (nonatomic) float networkTaskPriority;
@property (nonatomic, strong) NSArray<MCSHLSURIItem *> *URIItems;
@property (nonatomic) NSUInteger TsCount;
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
        URI = index < _URIItems.count ? _URIItems[index].URI : nil;
    });
    return URI;
}

- (nullable NSDictionary *)HTTPAdditionalHeadersAtIndex:(NSUInteger)index {
    __block NSDictionary *headers = nil;
    dispatch_sync(mcs_queue, ^{
        headers = index < _URIItems.count ? _URIItems[index].HTTPAdditionalHeaders : nil;
    });
    return headers;
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
        count = _TsCount;
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
    
    if ( contents == nil || ![contents hasPrefix:HLS_PREFIX_FILE_FIRST_LINE] ) {
        [self _onError:[NSError mcs_errorWithCode:MCSFileError userInfo:@{
            MCSErrorUserInfoObjectKey : contents ?: @"",
            MCSErrorUserInfoReasonKey : @"数据为空或格式不正确!"
        }]];
        return;
    }
 
    NSMutableString *indexFileContents = contents.mutableCopy;
    ///
    /// #EXTINF:10,
    /// #EXT-X-BYTERANGE:1007868@0
    /// 000000.ts
    ///
    NSArray<NSValue *> *TsURIRanges = [contents mcs_TsURIRanges];
    if ( TsURIRanges.count == 0 ) {
        [self _onError:[NSError mcs_errorWithCode:MCSFileError userInfo:@{
            MCSErrorUserInfoObjectKey : contents,
            MCSErrorUserInfoReasonKey : @"数据格式不正确, 未匹配到ts文件!"
        }]];
        return;
    }
    
    [TsURIRanges enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSValue * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange range = [obj rangeValue];
        NSString *matched = [contents substringWithRange:range];
        NSString *url = [matched mcs_convertToUrlByContentsURL:currRequest.URL];
        NSString *proxy = [MCSURL.shared proxyTsURIWithUrl:url inAsset:asset.name];
        [indexFileContents replaceCharactersInRange:range withString:proxy];
    }];
 
    ///
    /// #EXT-X-KEY:METHOD=AES-128,URI="...",IV=...
    ///
    [[indexFileContents mcs_textCheckingResultsByMatchPattern:HLS_REGEX_AESKEY options:kNilOptions] enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSTextCheckingResult * _Nonnull result, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange URIRange = [result rangeAtIndex:HLS_INDEX_AESKEY];
        NSString *URI = [indexFileContents substringWithRange:URIRange];
        NSString *url = [URI mcs_convertToUrlByContentsURL:currRequest.URL];
        NSString *proxy = [MCSURL.shared proxyAESKeyURIWithUrl:url inAsset:asset.name];
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
    NSString *redirectUrl = [contents mcs_urlsByMatchingPattern:HLS_REGEX_INDEX contentsURL:contentsURL options:NSRegularExpressionAnchorsMatchLines].firstObject;
    // 2
    if ( redirectUrl == nil ) {
        redirectUrl = [contents mcs_urlsByMatchingPattern:HLS_REGEX_INDEX_2 atIndex:HLS_INDEX_INDEX_2 contentsURL:contentsURL options:kNilOptions].firstObject;
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
    
    _URIItems = [content mcs_URIItems];
    NSInteger TsCount = 0;
    for ( MCSHLSURIItem *item in _URIItems ) {
        if ( item.type == MCSDataTypeHLSTs ) TsCount += 1;
    }
    
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
- (nullable NSArray<NSValue *> *)mcs_rangesByMatchingPattern:(NSString *)pattern options:(NSRegularExpressionOptions)options {
    NSMutableArray<NSValue *> *m = NSMutableArray.array;
    for ( NSTextCheckingResult *result in [self mcs_textCheckingResultsByMatchPattern:pattern options:options])
        [m addObject:[NSValue valueWithRange:result.range]];
    return m.count != 0 ? m.copy : nil;
}

- (nullable NSArray<NSTextCheckingResult *> *)mcs_textCheckingResultsByMatchPattern:(NSString *)pattern options:(NSRegularExpressionOptions)options {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:options error:NULL];
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
- (nullable NSArray<NSString *> *)mcs_urlsByMatchingPattern:(NSString *)pattern contentsURL:(NSURL *)contentsURL options:(NSRegularExpressionOptions)options {
    return [self mcs_urlsByMatchingPattern:pattern atIndex:0 contentsURL:contentsURL options:options];
}

- (nullable NSArray<NSString *> *)mcs_urlsByMatchingPattern:(NSString *)pattern atIndex:(NSInteger)index contentsURL:(NSURL *)contentsURL options:(NSRegularExpressionOptions)options {
    NSMutableArray<NSString *> *m = NSMutableArray.array;
    [[self mcs_textCheckingResultsByMatchPattern:pattern options:options] enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
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

- (nullable NSArray<NSValue *> *)mcs_TsURIRanges {
    NSArray<NSString *> *lines = [self componentsSeparatedByString:@"\n"];
    NSMutableArray<NSValue *> *m = nil;
    BOOL tsFlag = NO;
    NSInteger length = 0;
    for ( NSString *line in lines ) {
        if ( tsFlag && ![line hasPrefix:HLS_PREFIX_TAG] ) {
            if ( m == nil ) m = NSMutableArray.array;
            [m addObject:[NSValue valueWithRange:NSMakeRange(length, line.length)]];
            tsFlag = NO;
        }
        
        if ( [line hasPrefix:HLS_PREFIX_TS_DURATION] )
            tsFlag = YES;
        
        length += line.length + 1;
    }
    return m.copy;
}

- (nullable NSArray<MCSHLSURIItem *> *)mcs_URIItems {
    NSArray<NSString *> *lines = [self componentsSeparatedByString:@"\n"];
    NSMutableArray<MCSHLSURIItem *> *m = NSMutableArray.array;
    BOOL tsFlag = NO;
    NSRange byteRange = NSMakeRange(0, 0);
    for ( NSString *line in lines ) {
        //    #EXT-X-KEY:METHOD=AES-128,URI="key1.php"
        //
        //    #EXTINF:2.833,
        //    example/0.ts
        //    #EXTINF:15.0,
        //    example/1.ts
        //
        //    #EXT-X-KEY:METHOD=AES-128,URI="key2.php"
        
        // AESKey
        if      ( [line hasPrefix:HLS_PREFIX_AESKEY] ) {
            NSRange range = [[line mcs_rangesByMatchingPattern:HLS_REGEX_AESKEY options:kNilOptions].firstObject rangeValue];
            NSString *URI = [line substringWithRange:range];
            [m addObject:[MCSHLSURIItem.alloc initWithType:MCSDataTypeHLSAESKey URI:URI HTTPAdditionalHeaders:nil]];
        }
        // Ts
        else if ( [line hasPrefix:HLS_PREFIX_TS_DURATION] ) {
            tsFlag = YES;
        }
        else if ( tsFlag ) {
            if      ( [line hasPrefix:HLS_PREFIX_TS_BYTERANGE] ) {
                NSTextCheckingResult *result = [line mcs_textCheckingResultsByMatchPattern:HLS_REGEX_TS_BYTERANGE options:kNilOptions].firstObject;
                long long location = [[line substringWithRange:[result rangeAtIndex:HLS_INDEX_TS_BYTERANGE_LOCATION]] longLongValue];
                long long length = [[line substringWithRange:[result rangeAtIndex:HLS_INDEX_TS_BYTERANGE_LENGTH]] longLongValue];
                byteRange = NSMakeRange(location, length);
            }
            else if ( ![line hasPrefix:HLS_PREFIX_TAG] ) {
                NSString *URI = line;
                NSDictionary *headers = nil;
                if ( byteRange.length != 0 )
                    headers = @{
                        @"Range" : [NSString stringWithFormat:@"bytes=%lu-%lu", (unsigned long)byteRange.location, NSMaxRange(byteRange) - 1]
                    };
                [m addObject:[MCSHLSURIItem.alloc initWithType:MCSDataTypeHLSTs URI:URI HTTPAdditionalHeaders:headers]];
                tsFlag = NO;
            }
        }
    }
    return m.count != 0 ? m.copy : nil;
}
@end
