//
//  HLSAssetParser.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "HLSAssetParser.h"
#import "MCSError.h"
#import "MCSURL.h"
#import "NSURLRequest+MCS.h"
#import "MCSConsts.h"
#import "MCSUtils.h"
#import "NSArray+MCS.h"

// https://tools.ietf.org/html/rfc8216

static NSString *const EXT_X_KEY = @"#EXT-X-KEY:";
static NSString *const EXTINF = @"#EXTINF:";
static NSString *const EXT_X_BYTERANGE = @"#EXT-X-BYTERANGE:";
static NSString *const EXT_X_MEDIA = @"#EXT-X-MEDIA:";
static NSString *const EXT_X_STREAM_INF = @"#EXT-X-STREAM-INF:";
static NSString *const EXT_X_I_FRAME_STREAM_INF = @"EXT-X-I-FRAME-STREAM-INF:";

static NSString *const HLS_ATTR_URI = @"URI";
static NSString *const HLS_ATTR_TYPE = @"TYPE";
static NSString *const HLS_ATTR_GROUP_ID = @"GROUP-ID";
static NSString *const HLS_ATTR_NAME = @"NAME";
static NSString *const HLS_ATTR_LANGUAGE = @"LANGUAGE";
static NSString *const HLS_ATTR_DEFAULT = @"DEFAULT";
static NSString *const HLS_ATTR_AUTOSELECT = @"AUTOSELECT";
static NSString *const HLS_ATTR_BANDWIDTH = @"BANDWIDTH";
static NSString *const HLS_ATTR_CODECS = @"CODECS";
static NSString *const HLS_ATTR_RESOLUTION = @"RESOLUTION";
static NSString *const HLS_ATTR_VIDEO = @"VIDEO";
static NSString *const HLS_ATTR_AUDIO = @"AUDIO";
static NSString *const HLS_ATTR_SUBTITLES = @"SUBTITLES";
static NSString *const HLS_ATTR_CLOSED_CAPTIONS = @"CLOSED-CAPTIONS";
static NSString *const HLS_ATTR_AVERAGE_BANDWIDTH = @"AVERAGE-BANDWIDTH";
static NSString *const HLS_ATTR_FRAME_RATE = @"FRAME-RATE";

static NSString *const HLS_CTX_BYTERANGE_PREV_END = @"BYTERANGE_PREV_END";
static NSString *const HLS_CTX_LAST_ITEM = @"LAST_ITEM";

@interface HLSItem : NSObject<HLSItem>
@property (nonatomic, copy, nullable) NSString *URI;
@property (nonatomic) NSUInteger URIStartPosition;
@property (nonatomic) NSUInteger startPosition;
@property (nonatomic) NSUInteger length;
@end

@implementation HLSItem
- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { URL: %@, URLStartPosition: %ld }", self.class, self, _URI, _URIStartPosition];
}
@end

@interface HLSItem (Subclass)
@property (nonatomic, readonly) HLSItemType itemType;
@property (nonatomic, strong, readonly, nullable) NSString *fileExtension;
@end

@interface HLSKey : HLSItem<HLSKey>
//typedef NS_ENUM(NSUInteger, HLSKeyMethod) {
//    HLSKeyMethodNone,        // "NONE"
//    HLSKeyMethodAES128,      // "AES-128"
//    HLSKeyMethodSampleAES    // "SAMPLE-AES"
//};
//@property (nonatomic, readonly) HLSKeyMethod method;                            // ignored; 加密方法
//@property (nonatomic, copy, readonly, nullable) NSString *IV;                   // ignored; 可选的初始化向量
//@property (nonatomic, copy, readonly, nullable) NSString *keyFormat;            // ignored; 可选的密钥格式
//@property (nonatomic, copy, readonly, nullable) NSString *keyFormatVersions;    // ignored; 可选的密钥格式版本
@end

@implementation HLSKey
- (HLSItemType)itemType {
    return HLSItemTypeKey;
}
- (NSString *)fileExtension {
    return HLS_EXTENSION_KEY;
}
@end


/// #EXTINF: https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.2.1
/// #EXT-X-BYTERANGE: https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.2.2
@interface HLSSegment : HLSItem<HLSSegment>
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) NSRange byteRange; // #EXT-X-BYTERANGE or { NSNotFound, NSNotFound }
@end

@implementation HLSSegment
- (instancetype)init {
    self = [super init];
    _byteRange = (NSRange){ NSNotFound, NSNotFound };
    return self;
}
- (HLSItemType)itemType {
    return HLSItemTypeSegment;
}
- (NSString *)fileExtension {
    return HLS_EXTENSION_SEGMENT;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { URL: %@, URLStartPosition: %ld, duration: %lf, byteRange: %@ }", self.class, self, self.URI, self.URIStartPosition, _duration, NSStringFromRange(_byteRange)];
}
@end

/// #EXT-X-STREAM-INF: https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.4.2
@interface HLSVariantStream : HLSItem<HLSVariantStream>
@property (nonatomic) NSUInteger bandwidth;               // REQUIRED: BANDWIDTH attribute
@property (nonatomic) NSUInteger averageBandwidth;        // OPTIONAL: AVERAGE-BANDWIDTH attribute
@property (nonatomic, copy, nullable) NSString *codecs;   // OPTIONAL: CODECS attribute
@property (nonatomic, copy, nullable) NSString *resolution; // OPTIONAL: RESOLUTION attribute
@property (nonatomic, copy, nullable) NSString *frameRate; // OPTIONAL: FRAME-RATE attribute
@property (nonatomic, copy, nullable) NSString *audioGroupID; // OPTIONAL: AUDIO group ID
@property (nonatomic, copy, nullable) NSString *videoGroupID; // OPTIONAL: VIDEO group ID
@property (nonatomic, copy, nullable) NSString *subtitlesGroupID; // OPTIONAL: SUBTITLES group ID
@property (nonatomic, copy, nullable) NSString *closedCaptionsGroupID; // OPTIONAL: CLOSED-CAPTIONS group ID
@end

@implementation HLSVariantStream
- (HLSItemType)itemType {
    return HLSItemTypeVariantStream;
}
- (NSString *)fileExtension {
    return HLS_EXTENSION_PLAYLIST;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { URL: %@, URLStartPosition: %ld, bandwidth: %lu, averageBandwidth: %lu, codecs: %@, resolution: %@, frameRate: %@, audioGroupID: %@, videoGroupID: %@, subtitlesGroupID: %@, closedCaptionsGroupID: %@ }", self.class, self, self.URI, self.URIStartPosition, _bandwidth, _averageBandwidth, _codecs, _resolution, _frameRate, _audioGroupID, _videoGroupID, _subtitlesGroupID, _closedCaptionsGroupID];
}
@end

@interface HLSIFrameStream : HLSItem<HLSIFrameStream>
@property (nonatomic) NSUInteger bandwidth;             // REQUIRED: BANDWIDTH attribute
@property (nonatomic, copy, nullable) NSString *codecs;   // OPTIONAL: CODECS attribute
@property (nonatomic, copy, nullable) NSString *resolution; // OPTIONAL: RESOLUTION attribute
@property (nonatomic, copy, nullable) NSString *videoGroupID; // OPTIONAL: VIDEO group ID
@end

@implementation HLSIFrameStream
- (HLSItemType)itemType {
    return HLSItemTypeIFrameStream;
}
- (NSString *)fileExtension {
    return HLS_EXTENSION_PLAYLIST;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { URL: %@, URLStartPosition: %ld, bandwidth: %lu, codecs: %@, resolution: %@, videoGroupID: %@ }", self.class, self, self.URI, self.URIStartPosition, _bandwidth, _codecs, _resolution, _videoGroupID];
}
@end

/// #EXT-X-MEDIA: https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.4.1
@interface HLSRendition : HLSItem<HLSRendition>
@property (nonatomic) HLSRenditionType renditionType;
@property (nonatomic, copy) NSString *groupId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, nullable) NSString *language;
@property (nonatomic) BOOL isDefault;
@property (nonatomic) BOOL isAutoSelect;
@end

@implementation HLSRendition
- (HLSItemType)itemType {
    return HLSItemTypeRendition;
}
- (NSString *)fileExtension {
    switch ( _renditionType ) {
        case HLSRenditionTypeAudio:
        case HLSRenditionTypeVideo:
            return HLS_EXTENSION_PLAYLIST;
        case HLSRenditionTypeSubtitles:
            return HLS_EXTENSION_SUBTITLES;
        case HLSRenditionTypeClosedCaptions:
            return nil; // no file, ignored;
    }
}
- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { URL: %@, URLStartPosition: %ld, renditionType: %ld, groupId: %@, name: %@, language: %@, isDefault: %d, isAutoSelect: %d }", self.class, self, self.URI, self.URIStartPosition, _renditionType, _groupId, _name, _language, _isDefault, _isAutoSelect];
}
@end

/// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.4.1.1
///
/// #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="en",URI="audio_eng.m3u8"
/// #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Spanish",LANGUAGE="es",URI="audio_spa.m3u8"
///
/// #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",URI="subs_eng.m3u8"
/// #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Spanish",LANGUAGE="es",URI="subs_spa.m3u8"
///
/// A set of one or more EXT-X-MEDIA tags with the same GROUP-ID value
/// and the same TYPE value defines a Group of Renditions.  Each member
/// of the Group MUST be an alternative Rendition of the same content;
/// otherwise, playback errors can occur.
@interface HLSRenditionGroup : HLSItem<HLSRenditionGroup>
@property (nonatomic, copy) NSString *groupId;
@property (nonatomic) HLSRenditionType renditionType;
@property (nonatomic, copy, readonly) NSArray<id<HLSRendition>> *renditions; // HLSRenditionType
@end

@implementation HLSRenditionGroup {
    NSMutableArray<id<HLSRendition>> *mRenditions;
}
- (instancetype)init {
    self = [super init];
    mRenditions = NSMutableArray.array;
    return self;
}
- (void)addRendition:(id<HLSRendition>)rendition {
    [mRenditions addObject:rendition];
}
- (NSArray<id<HLSRendition>> *)renditions {
    return mRenditions;
}
- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { groupId: %@, renditionType: %ld, renditions: %@ }", self.class, self, _groupId, _renditionType, mRenditions];
}
@end

@interface NSString (HLS)
/// 如果value前后包含双引号, 则引号会被去除;
///
/// #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="en",URI="audio_eng.m3u8"
/// #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Spanish",LANGUAGE="es",URI="audio_spa.m3u8"
///
/// #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",URI="subs_eng.m3u8"
/// #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Spanish",LANGUAGE="es",URI="subs_spa.m3u8"
- (nullable NSString *)hls_findValueForAttribute:(NSString *)attribute startPos:(NSUInteger *)startPosPtr;
- (HLSRenditionType)hls_toRenditionType;
- (BOOL)hls_toBOOL;
- (NSString *)hls_restoreOriginalUrl:(NSURL *)URL; // 将路径转换为原始url
@end

@implementation NSString (HLS)
- (nullable NSString *)hls_findValueForAttribute:(NSString *)name startPos:(NSUInteger *)startPosPtr {
    NSArray<NSString *> *attributePairs = [self componentsSeparatedByString:@","];
    NSString *prefix = [name stringByAppendingString:@"="];
    __block NSUInteger startPos = 0;
    NSString *pair = [attributePairs mcs_firstOrNull:^BOOL(NSString * _Nonnull obj) {
        if ( [obj hasPrefix:prefix] ) return YES;
        startPos += obj.length + 1; // + @",".length();
        return NO;
    }];
    if ( pair != nil ) {
        startPos += prefix.length;
        NSArray<NSString *> *keyValue = [pair componentsSeparatedByString:@"="];
        NSString *value = keyValue[1];
        if ( [value hasPrefix:@"\""] ) { // 移除双引号;
            startPos += 1; // @"\"".length();
            value = [value stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
        }
        if ( startPosPtr != NULL ) *startPosPtr = startPos;
        return value;
    }
    return nil;
}

/// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.4.1
/// valid strings are AUDIO, VIDEO, SUBTITLES, and CLOSED-CAPTIONS.
- (HLSRenditionType)hls_toRenditionType {
    if ( [self isEqualToString:HLS_ATTR_AUDIO] ) return HLSRenditionTypeAudio;
    if ( [self isEqualToString:HLS_ATTR_VIDEO] ) return HLSRenditionTypeVideo;
    if ( [self isEqualToString:HLS_ATTR_SUBTITLES] ) return HLSRenditionTypeSubtitles;
    return HLSRenditionTypeClosedCaptions;
}

- (BOOL)hls_toBOOL {
    if ( [self isEqualToString:@"YES"] ) return YES;
    return NO;
}

- (NSString *)hls_restoreOriginalUrl:(NSURL *)resourceURL {
    static NSString *const HLS_PREFIX_LOCALHOST = @"http://localhost";
    static NSString *const HLS_PREFIX_DIR_ROOT = @"/";
    static NSString *const HLS_PREFIX_DIR_PARENT = @"../";
    static NSString *const HLS_PREFIX_DIR_CURRENT = @"./";
     
    NSString *url = nil;
    /// /video/name.m3u8
    ///
    if      ( [self hasPrefix:HLS_PREFIX_DIR_ROOT] ) {
        NSURL *rootDir = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", resourceURL.scheme, resourceURL.host]];
        NSString *subpath = self;
        url = [rootDir mcs_URLByAppendingPathComponent:subpath].absoluteString;
    }
    /// ../video/name.m3u8
    /// ../../video/name.m3u8
    ///
    else if ( [self hasPrefix:HLS_PREFIX_DIR_PARENT] ) {
        NSURL *curDir = resourceURL.mcs_URLByRemovingLastPathComponentAndQuery;
        NSURL *parentDir = curDir;
        NSString *subpath = self;
        while ( [subpath hasPrefix:HLS_PREFIX_DIR_PARENT] ) {
            parentDir = parentDir.mcs_URLByRemovingLastPathComponentAndQuery;
            subpath = [subpath substringFromIndex:HLS_PREFIX_DIR_PARENT.length];
        }
        url = [parentDir mcs_URLByAppendingPathComponent:subpath].absoluteString;
    }
    /// ./video/name.m3u8
    else if ( [self hasPrefix:HLS_PREFIX_DIR_CURRENT] ) {
        NSURL *curDir = resourceURL.mcs_URLByRemovingLastPathComponentAndQuery;
        NSString *subpath = [self substringFromIndex:HLS_PREFIX_DIR_CURRENT.length];
        url = [curDir mcs_URLByAppendingPathComponent:subpath].absoluteString;
    }
    /// http://localhost
    else if ( [self hasPrefix:HLS_PREFIX_LOCALHOST] ) {
        NSURL *rootDir = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@", resourceURL.scheme, resourceURL.host]];
        NSString *subpath = [self substringFromIndex:HLS_PREFIX_LOCALHOST.length];
        url = [rootDir mcs_URLByAppendingPathComponent:subpath].absoluteString;
    }
    else if ( [self containsString:@"://"] ) {
        url = self;
    }
    else {
        NSURL *curDir = resourceURL.mcs_URLByRemovingLastPathComponentAndQuery;
        NSString *subpath = self;
        url = [curDir mcs_URLByAppendingPathComponent:subpath].absoluteString;
    }
    return url;
}
@end

@interface HLSAssetParser () {
    NSArray<id<HLSItem>> *_Nullable mAllItems;
    NSArray<id<HLSKey>> *_Nullable mKeys;
    NSArray<id<HLSSegment>> *_Nullable mSegments;
//    NSArray<id<HLSVariantStream>> *_Nullable mVariantStreams;
//    NSArray<id<HLSIFrameStream>> *_Nullable mIFrameStreams;
//    NSDictionary<NSString *, id<HLSRenditionGroup>> *_Nullable mGroups;
    id<HLSVariantStream> _Nullable mSelectedVariantStream;
    id<HLSRendition> _Nullable mSelectedAudioRendition;
    id<HLSRendition> _Nullable mSelectedVideoRendition;
    id<HLSRendition> _Nullable mSelectedSubtitlesRendition;
}
@end

@implementation HLSAssetParser
+ (nullable NSString *)proxyPlaylistWithAsset:(NSString *)assetName
                                  originalURL:(NSURL *)originalURL
                                   currentURL:(NSURL *)currentURL
                                     playlist:(NSData *)rawData
                variantStreamSelectionHandler:(nullable HLSVariantStreamSelectionHandler)variantStreamSelectionHandler
                    renditionSelectionHandler:(nullable HLSRenditionSelectionHandler)renditionSelectionHandler
                                        error:(out NSError **)errorPtr {
    NSString *_Nullable playlist = [NSString.alloc initWithData:rawData encoding:NSUTF8StringEncoding] ?: [NSString.alloc initWithData:rawData encoding:1];
    NSError *error = nil;
    if ( playlist == nil || ![playlist hasPrefix:@"#EXT"] ) {
        error = [NSError mcs_errorWithCode:MCSFileError userInfo:@{
            MCSErrorUserInfoObjectKey : playlist ?: @"",
            MCSErrorUserInfoReasonKey : @"Empty data or unsupported format!"
        }];
    }
    
    NSMutableString *_Nullable proxyPlaylist = nil;;
    if ( playlist != nil ) {
        NSMutableArray<__kindof HLSItem *> *parsingItems = NSMutableArray.array;
        proxyPlaylist = (NSMutableString *)[self parse:playlist shouldTrim:YES parsingItems:parsingItems];
        
        __block NSMutableArray<id<HLSVariantStream>> *_Nullable variantStreams;
        __block NSMutableDictionary<NSString *, HLSRenditionGroup *> *_Nullable renditionGroups;
        [parsingItems enumerateObjectsUsingBlock:^(__kindof HLSItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            switch ( obj.itemType ) {
                case HLSItemTypeKey:
                case HLSItemTypeSegment:
                case HLSItemTypeIFrameStream:
                    break;
                case HLSItemTypeVariantStream: {
                    if ( variantStreams == nil ) variantStreams = NSMutableArray.array;
                    [variantStreams addObject:obj];
                    break;
                }
                case HLSItemTypeRendition: {
                    if ( renditionGroups == nil ) renditionGroups = NSMutableDictionary.dictionary;
                    HLSRendition *rendition = obj;
                    NSString *key = [rendition.groupId stringByAppendingFormat:@"_%ld", rendition.renditionType];
                    HLSRenditionGroup *group = renditionGroups[key];
                    if ( group == nil ) {
                        group = [HLSRenditionGroup.alloc init];
                        renditionGroups[key] = group;
                    }
                    [group addRendition:rendition];
                    break;
                }
            }
        }];
        
        // selected variant stream
        id<HLSVariantStream> _Nullable selectedVariantStream = nil;
        // selected renditions
        id<HLSRendition> _Nullable selectedAudioRendition = nil;
        id<HLSRendition> _Nullable selectedVideoRendition = nil;
        id<HLSRendition> _Nullable selectedSubtitlesRendition = nil;
        if ( variantStreams != nil ) {
            selectedVariantStream = [self selectVariantStreamInArray:variantStreams originalURL:originalURL currentURL:currentURL variantStreamSelectionHandler:variantStreamSelectionHandler];
            NSParameterAssert(selectedVariantStream != nil);
            NSString *audioGroupID = selectedVariantStream.audioGroupID;
            NSString *videoGroupID = selectedVariantStream.videoGroupID;
            NSString *subtitlesGroupID = selectedVariantStream.subtitlesGroupID;
//            if ( audioGroupID != nil ) {
//                NSString *key = [audioGroupID stringByAppendingFormat:@"_%ld", HLSRenditionTypeAudio];
//                HLSRenditionGroup *group = renditionGroups[key];
//                NSParameterAssert(group != nil);
//                selectedAudioRendition = 
//                    group.renditions.count > 1 ? [self selectRenditionInGroup:group originalURL:originalURL currentURL:currentURL renditionSelectionHandler:renditionSelectionHandler] :
//                                                 group.renditions.firstObject;
//            }
            if ( audioGroupID != nil ) selectedAudioRendition = [self selectRenditionInGroups:renditionGroups
                                                                                      groupId:audioGroupID
                                                                                renditionType:HLSRenditionTypeAudio
                                                                                  originalURL:originalURL
                                                                                   currentURL:currentURL
                                                                    renditionSelectionHandler:renditionSelectionHandler];
            if ( videoGroupID != nil ) selectedVideoRendition = [self selectRenditionInGroups:renditionGroups
                                                                                      groupId:videoGroupID
                                                                                renditionType:HLSRenditionTypeVideo
                                                                                  originalURL:originalURL
                                                                                   currentURL:currentURL
                                                                    renditionSelectionHandler:renditionSelectionHandler];
            if ( subtitlesGroupID != nil ) selectedSubtitlesRendition = [self selectRenditionInGroups:renditionGroups
                                                                                              groupId:subtitlesGroupID
                                                                                        renditionType:HLSRenditionTypeSubtitles
                                                                                          originalURL:originalURL
                                                                                           currentURL:currentURL
                                                                            renditionSelectionHandler:renditionSelectionHandler];
        }
        
        [parsingItems enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(__kindof HLSItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            BOOL shouldRemove = NO;
            switch (obj.itemType) {
                case HLSItemTypeKey:
                case HLSItemTypeSegment:
                    break;
                case HLSItemTypeVariantStream: {
                    // remove unselected variant streams
                    shouldRemove = obj != selectedVariantStream;
                    break;
                }
                case HLSItemTypeRendition: {
                    // remove unselected renditions
                    shouldRemove = !(obj == selectedAudioRendition || obj == selectedVideoRendition || obj == selectedSubtitlesRendition);
                    break;
                }
                case HLSItemTypeIFrameStream: {
                    // remove iframe streams
                    shouldRemove = YES;
                    break;
                }
            }
            
            // remove contents
            if ( shouldRemove ) {
                [proxyPlaylist replaceCharactersInRange:NSMakeRange(obj.startPosition, obj.length) withString:@""];
                return; // return;
            }
            
            // replace URI with proxy url
            NSString *URI = obj.URI;
            if ( URI == nil ) return;
            NSString *extension = obj.fileExtension;
            if ( extension == nil ) return;
            NSString *originalUrl = [URI hls_restoreOriginalUrl:currentURL];
            NSString *proxy = [MCSURL.shared generateProxyURIFromHLSOriginalURL:[NSURL URLWithString:originalUrl] extension:extension forAsset:assetName];
            [proxyPlaylist replaceCharactersInRange:NSMakeRange(obj.URIStartPosition, URI.length) withString:proxy];
        }];
    }
    if ( error != nil && errorPtr != NULL ) *errorPtr = error;
    return proxyPlaylist != nil ? proxyPlaylist.copy : nil;
}

+ (NSString *)parse:(NSString *)playlist shouldTrim:(BOOL)shouldTrim parsingItems:(NSMutableArray<__kindof HLSItem *> *)parsingItems {
    NSMutableString *_Nullable trimmedPlaylist = NSMutableString.string;
    NSMutableDictionary *ctx = NSMutableDictionary.dictionary;
    NSArray *lines = [playlist componentsSeparatedByString:@"\n"];
    NSInteger lastLineIndex = lines.count - 1;
    __block NSUInteger offset = 0;
    [lines enumerateObjectsUsingBlock:^(NSString *line, NSUInteger idx, BOOL * _Nonnull stop) {
        // 去除行首尾的空白字符; 每一行要么是一个标签(以 #EXT 开头), 要么是一个 URI
        NSString *trimmedLine = shouldTrim ? [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : line;
        // 跳过空行和注释
        if      ( [trimmedLine hasPrefix:@"#EXT"] ) [self handleTag:trimmedLine offset:offset parsingItems:parsingItems context:ctx]; // 这是一个标签行
        else if ( ![trimmedLine isEqualToString:@""] ) [self handleURI:trimmedLine offset:offset context:ctx]; // 这是一个 URI 行
        if ( shouldTrim ) idx != lastLineIndex ? [trimmedPlaylist appendFormat:@"%@\n", trimmedLine] : [trimmedPlaylist appendString:trimmedLine];
        offset += trimmedLine.length + 1; // + @"\n"
    }];
    return shouldTrim ? trimmedPlaylist : playlist;
}

/// offset: filePointer offset
+ (void)handleTag:(NSString *)tagLine offset:(NSUInteger)offset parsingItems:(NSMutableArray<__kindof HLSItem *> *)parsingItems context:(NSMutableDictionary *)ctx {
    /// #EXTINF:8.766667,
    /// #EXT-X-BYTERANGE:9194528@9662832
    /// segment.ts
    if      ( [tagLine hasPrefix:EXTINF] ) {
        HLSSegment *segment = [HLSSegment.alloc init];
        NSString *duration = [tagLine substringFromIndex:EXTINF.length];
        segment.duration = duration.doubleValue;
        segment.startPosition = offset;
        [parsingItems addObject:segment];
        ctx[HLS_CTX_LAST_ITEM] = segment;
    }
    /// #EXTINF:8.766667,
    /// #EXT-X-BYTERANGE:9194528@9662832
    /// segment.ts
    else if ( [tagLine hasPrefix:EXT_X_BYTERANGE] ) {
        HLSSegment *segment = ctx[HLS_CTX_LAST_ITEM];
        NSParameterAssert([segment isKindOfClass:HLSSegment.class]);
        NSString *byteRange = [tagLine substringFromIndex:EXT_X_BYTERANGE.length];
        NSNumber *prevEnd = ctx[HLS_CTX_BYTERANGE_PREV_END];
        segment.byteRange = [self parseByteRange:byteRange prevEnd:prevEnd.longLongValue];
        ctx[HLS_CTX_BYTERANGE_PREV_END] = @(NSMaxRange(segment.byteRange));
    }
    /// #EXT-X-KEY: https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.2.4
    ///
    /// #EXT-X-KEY:METHOD=NONE 这种情况下, 不需要 URI 和 IV, 表示后续的媒体段不加密;
    /// #EXT-X-KEY:METHOD=AES-128,URI="https://example.com/key",IV=0x1a2b3c4d5e6f7g8h9i0jklmnopqrst
    /// #EXT-X-KEY:METHOD=AES-128,URI="https://example.com/key"
    /// #EXT-X-KEY:METHOD=SAMPLE-AES,URI="https://example.com/key",KEYFORMAT="com.apple.streamingkeydelivery",KEYFORMATVERSIONS="1"
    /// #EXT-X-KEY:METHOD=SAMPLE-AES,URI="https://drm.example.com/widevine-key",KEYFORMAT="com.widevine.alpha",KEYFORMATVERSIONS="1/2"
    else if ( [tagLine hasPrefix:EXT_X_KEY] ) {
        NSString *attributesString = [tagLine substringFromIndex:EXT_X_KEY.length];
        NSUInteger startPos = 0; // URI startPos
        NSString *URI = [attributesString hls_findValueForAttribute:HLS_ATTR_URI startPos:&startPos];
        if ( URI != nil ) {
            HLSKey *key = [HLSKey.alloc init];
            key.URI = URI;
            key.URIStartPosition = EXT_X_KEY.length + startPos + offset;
            key.startPosition = offset;
            key.length = tagLine.length;
            [parsingItems addObject:key];
        }
    }
    /// #EXT-X-MEDIA: https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.4.1
    ///
    /// #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="en",URI="audio_eng.m3u8"
    /// #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Spanish",LANGUAGE="es",URI="audio_spa.m3u8"
    ///
    /// #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",URI="subs_eng.m3u8"
    /// #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Spanish",LANGUAGE="es",URI="subs_spa.m3u8"
    else if ( [tagLine hasPrefix:EXT_X_MEDIA] ) {
        NSString *attributesString = [tagLine substringFromIndex:EXT_X_MEDIA.length];
        HLSRenditionType renditionType = [[attributesString hls_findValueForAttribute:HLS_ATTR_TYPE startPos:NULL] hls_toRenditionType];
        NSString *groupId = [attributesString hls_findValueForAttribute:HLS_ATTR_GROUP_ID startPos:NULL];
        NSString *name = [attributesString hls_findValueForAttribute:HLS_ATTR_NAME startPos:NULL];
        NSString *language = [attributesString hls_findValueForAttribute:HLS_ATTR_LANGUAGE startPos:NULL];
        BOOL isDefault = [attributesString hls_findValueForAttribute:HLS_ATTR_DEFAULT startPos:NULL];
        BOOL isAutoSelect = [attributesString hls_findValueForAttribute:HLS_ATTR_AUTOSELECT startPos:NULL];
        NSUInteger startPos = 0;
        NSString *URI = renditionType != HLSRenditionTypeClosedCaptions ? [attributesString hls_findValueForAttribute:HLS_ATTR_URI startPos:&startPos] : nil;
        HLSRendition *rendition = [HLSRendition.alloc init];
        rendition.renditionType = renditionType;
        rendition.groupId = groupId;
        rendition.name = name;
        rendition.language = language;
        rendition.isDefault = isDefault;
        rendition.isAutoSelect = isAutoSelect;
        rendition.startPosition = offset;
        rendition.length = tagLine.length;
        if ( renditionType != HLSRenditionTypeClosedCaptions ) {
            rendition.URI = URI;
            rendition.URIStartPosition = EXT_X_MEDIA.length + startPos + offset;
        }
        [parsingItems addObject:rendition];
    }
    /// #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360,CODECS="avc1.4d401e,mp4a.40.2",AUDIO="audio-group"
    /// https://example.com/low/index.m3u8
    ///
    /// #EXT-X-STREAM-INF:BANDWIDTH=3000000,AVERAGE-BANDWIDTH=2500000,RESOLUTION=1280x720,FRAME-RATE=60,CODECS="avc1.4d4028,mp4a.40.2",AUDIO="audio-group",SUBTITLES="subs-group"
    /// https://example.com/high/index.m3u8
    else if ( [tagLine hasPrefix:EXT_X_STREAM_INF] ) {
        NSString *attributesString = [tagLine substringFromIndex:EXT_X_STREAM_INF.length];
        NSUInteger bandwidth = [[attributesString hls_findValueForAttribute:HLS_ATTR_BANDWIDTH startPos:NULL] longLongValue];
        NSUInteger averageBandwidth = [[attributesString hls_findValueForAttribute:HLS_ATTR_AVERAGE_BANDWIDTH startPos:NULL] longLongValue];
        NSString *codecs = [attributesString hls_findValueForAttribute:HLS_ATTR_CODECS startPos:NULL];
        NSString *resolution = [attributesString hls_findValueForAttribute:HLS_ATTR_RESOLUTION startPos:NULL];
        NSString *frameRate = [attributesString hls_findValueForAttribute:HLS_ATTR_FRAME_RATE startPos:NULL];
        NSString *audioGroupID = [attributesString hls_findValueForAttribute:HLS_ATTR_AUDIO startPos:NULL];
        NSString *videoGroupID = [attributesString hls_findValueForAttribute:HLS_ATTR_VIDEO startPos:NULL];
        NSString *subtitlesGroupID = [attributesString hls_findValueForAttribute:HLS_ATTR_SUBTITLES startPos:NULL];
        NSString *closedCaptionsGroupID = [attributesString hls_findValueForAttribute:HLS_ATTR_CLOSED_CAPTIONS startPos:NULL];
        HLSVariantStream *variantSteam = [HLSVariantStream.alloc init];
        variantSteam.bandwidth = bandwidth;
        variantSteam.averageBandwidth = averageBandwidth;
        variantSteam.codecs = codecs;
        variantSteam.resolution = resolution;
        variantSteam.frameRate = frameRate;
        variantSteam.audioGroupID = audioGroupID;
        variantSteam.videoGroupID = videoGroupID;
        variantSteam.subtitlesGroupID = subtitlesGroupID;
        variantSteam.closedCaptionsGroupID = closedCaptionsGroupID;
        variantSteam.startPosition = offset;
        [parsingItems addObject:variantSteam];
        ctx[HLS_CTX_LAST_ITEM] = variantSteam;
    }
    /// #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=86000,URI="iframe-stream-1.m3u8"
    /// #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=150000,RESOLUTION=1920x1080,CODECS="avc1.4d001f",URI="iframe-stream-2.m3u8"
    /// #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=250000,RESOLUTION=1280x720,CODECS="avc1.42c01e",VIDEO="video-group-1",URI="iframe-stream-3.m3u8"
    /// #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=500000,RESOLUTION=854x480,CODECS="avc1.64001f",PROGRAM-ID=1,URI="iframe-stream-4.m3u8"
    /// #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=3840x2160,CODECS="hev1.1.6.L120.90",URI="iframe-stream-5.m3u8"
    else if ( [tagLine hasPrefix:EXT_X_I_FRAME_STREAM_INF] ) {
        NSString *attributesString = [tagLine substringFromIndex:EXT_X_I_FRAME_STREAM_INF.length];
        NSUInteger bandwidth = [[attributesString hls_findValueForAttribute:HLS_ATTR_BANDWIDTH startPos:NULL] longLongValue];
        NSString *codecs = [attributesString hls_findValueForAttribute:HLS_ATTR_CODECS startPos:NULL];
        NSString *resolution = [attributesString hls_findValueForAttribute:HLS_ATTR_RESOLUTION startPos:NULL];
        NSString *videoGroupID = [attributesString hls_findValueForAttribute:HLS_ATTR_VIDEO startPos:NULL];
        NSUInteger startPos = 0;
        NSString *URI = [attributesString hls_findValueForAttribute:HLS_ATTR_URI startPos:&startPos];
        HLSIFrameStream *iframeStream = [HLSIFrameStream.alloc init];
        iframeStream.bandwidth = bandwidth;
        iframeStream.codecs = codecs;
        iframeStream.resolution = resolution;
        iframeStream.videoGroupID = videoGroupID;
        iframeStream.URI = URI;
        iframeStream.URIStartPosition = EXT_X_I_FRAME_STREAM_INF.length + startPos + offset;
        iframeStream.startPosition = offset;
        iframeStream.length = tagLine.length;
        [parsingItems addObject:iframeStream];
    }
}

+ (void)handleURI:(NSString *)URI offset:(NSUInteger)offset context:(NSMutableDictionary *)ctx {
    HLSItem *item = ctx[HLS_CTX_LAST_ITEM];
    /// #EXTINF:8.766667,
    /// #EXT-X-BYTERANGE:9194528@9662832
    /// segment.ts
    ///
    ///
    /// #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360,CODECS="avc1.4d401e,mp4a.40.2",AUDIO="audio-group"
    /// https://example.com/low/index.m3u8
    ///
    if ( item != nil && item.URI == nil ) {
        item.URI = URI;
        item.URIStartPosition = offset;
        item.length = offset + URI.length - item.startPosition;
        ctx[HLS_CTX_LAST_ITEM] = nil;
    }
}

/// #EXT-X-BYTERANGE:<n>[@<o>]
+ (NSRange)parseByteRange:(NSString *)byteRange prevEnd:(NSUInteger)previousEnd {
    // 拆分 n 和 o, 分隔符是 "@"
    NSArray<NSString *> *components = [byteRange componentsSeparatedByString:@"@"];
    // 解析 n（字节长度）
    NSUInteger length = (NSUInteger)[components[0] integerValue];
    NSUInteger location;
    if (components.count > 1) {
        // 如果有 o, 解析 o（字节偏移量）
        location = (NSUInteger)[components[1] integerValue];
    } else {
        // 如果没有 o, 使用前一个片段的末尾作为起点
        location = previousEnd;
    }
    // 返回解析的 NSRange
    return NSMakeRange(location, length);
}

+ (id<HLSVariantStream>)selectVariantStreamInArray:(NSArray<id<HLSVariantStream>> *)streams 
                                       originalURL:(NSURL *)originalURL
                                        currentURL:(NSURL *)currentURL
                     variantStreamSelectionHandler:(nullable HLSVariantStreamSelectionHandler)variantStreamSelectionHandler {
    if ( variantStreamSelectionHandler != nil ) {
        return variantStreamSelectionHandler(streams, originalURL, currentURL);
    }
    return streams[streams.count / 2]; // select middle stream
}

+ (id<HLSRendition>)selectRenditionInGroups:(NSDictionary<NSString *, id<HLSRenditionGroup>> *)groups
                                    groupId:(NSString *)groupId
                              renditionType:(HLSRenditionType)renditionType
                                originalURL:(NSURL *)originalURL
                                 currentURL:(NSURL *)currentURL
                  renditionSelectionHandler:(nullable HLSRenditionSelectionHandler)renditionSelectionHandler {
    NSString *key = [groupId stringByAppendingFormat:@"_%ld", renditionType];
    id<HLSRenditionGroup> group = groups[key];
    NSParameterAssert(group != nil);
    NSArray<id<HLSRendition>> *renditions = group.renditions;
    if ( renditions.count > 1 ) {
        if ( renditionSelectionHandler != nil ) {
            return renditionSelectionHandler(renditionType, group, originalURL, currentURL);
        }
    }
    
    return [renditions mcs_firstOrNull:^BOOL(id<HLSRendition>  _Nonnull obj) {
        return obj.isDefault; // select default rendition
    }] ?: renditions.firstObject; // or first;
}

- (instancetype)initWithProxyPlaylist:(NSString *)playlist {
    self = [super init];
    NSMutableArray<__kindof HLSItem *> *parsingItems = NSMutableArray.array;
    [HLSAssetParser parse:playlist shouldTrim:NO parsingItems:parsingItems];
    if ( parsingItems.count != 0 ) {
        NSMutableArray<__kindof HLSItem *> *allItems = NSMutableArray.array;
        __block NSMutableArray<id<HLSKey>> *_Nullable keys;
        __block NSMutableArray<id<HLSSegment>> *_Nullable segments;
        __block NSMutableDictionary<NSString *, HLSRenditionGroup *> *_Nullable groups;
        __block id<HLSVariantStream> _Nullable selectedVariantStream;
        __block id<HLSRendition> _Nullable selectedAudioRendition;
        __block id<HLSRendition> _Nullable selectedVideoRendition;
        __block id<HLSRendition> _Nullable selectedSubtitlesRendition;
        [parsingItems enumerateObjectsUsingBlock:^(__kindof HLSItem * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            switch ( obj.itemType ) {
                case HLSItemTypeKey: {
                    if ( keys == nil ) keys = NSMutableArray.array;
                    [keys addObject:obj];
                    [allItems addObject:obj];
                    break;
                }
                case HLSItemTypeSegment: {
                    if ( segments == nil ) segments = NSMutableArray.array;
                    [segments addObject:obj];
                    [allItems addObject:obj];
                    break;
                }
                    // If there are variant streams in the m3u8, only one can be selected.
                case HLSItemTypeVariantStream: {
                    selectedVariantStream = obj;
                    [allItems addObject:obj];
                    break;
                }
                case HLSItemTypeIFrameStream: {
    //                if ( iframeStreams == nil ) iframeStreams = NSMutableArray.array;
    //                [iframeStreams addObject:obj];
                    break;
                }
                case HLSItemTypeRendition: {
                    // consider lib old versions
                    if ( groups == nil ) groups = NSMutableDictionary.dictionary;
                    HLSRendition *rendition = obj;
                    NSString *key = [rendition.groupId stringByAppendingFormat:@"_%ld", rendition.renditionType];
                    HLSRenditionGroup *group = groups[key];
                    if ( group == nil ) {
                        group = [HLSRenditionGroup.alloc init];
                        groups[key] = group;
                    }
                    [group addRendition:rendition];
                    break;
                }
            }
        }];
        if ( keys != nil ) mKeys = keys.copy;
        if ( segments != nil ) mSegments = segments.copy;
//        if ( variantStreams != nil ) mVariantStreams = variantStreams.copy;
//        if ( groups != nil ) mGroups = groups.copy;
        if ( selectedVariantStream != nil ) {
            mSelectedVariantStream = selectedVariantStream;
            NSString *audioGroupID = selectedVariantStream.audioGroupID;
            NSString *videoGroupID = selectedVariantStream.videoGroupID;
            NSString *subtitlesGroupID = selectedVariantStream.subtitlesGroupID;
            // consider lib old versions
            if ( audioGroupID != nil ) mSelectedAudioRendition = groups[[audioGroupID stringByAppendingFormat:@"_%ld", HLSRenditionTypeAudio]].renditions.firstObject;
            if ( videoGroupID != nil ) mSelectedVideoRendition = groups[[videoGroupID stringByAppendingFormat:@"_%ld", HLSRenditionTypeVideo]].renditions.firstObject;
            if ( subtitlesGroupID != nil ) mSelectedSubtitlesRendition = groups[[subtitlesGroupID stringByAppendingFormat:@"_%ld", HLSRenditionTypeSubtitles]].renditions.firstObject;
            if ( mSelectedAudioRendition != nil ) [allItems addObject:mSelectedAudioRendition];
            if ( mSelectedVideoRendition != nil ) [allItems addObject:mSelectedVideoRendition];
            if ( mSelectedSubtitlesRendition != nil ) [allItems addObject:mSelectedSubtitlesRendition];
        }
        if ( parsingItems.count > 0 ) mAllItems = allItems.copy;
    }
    return self;
}

- (NSUInteger)allItemsCount {
    return mAllItems != nil ? mAllItems.count : 0;
}

- (NSUInteger)segmentsCount {
    return mSegments != nil ? mSegments.count : 0;
}

- (nullable NSArray<id<HLSItem>> *)allItems {
    return mAllItems;
}

- (nullable NSArray<id<HLSKey>> *)keys {
    return mKeys;
}

- (nullable NSArray<id<HLSSegment>> *)segments {
    return mSegments;
}

//- (nullable NSArray<id<HLSVariantStream>> *)variantStreams {
//    return mVariantStreams;
//}
//
//- (nullable id<HLSRenditionGroup>)renditionGroupBy:(NSString *)groupId type:(HLSRenditionType)type {
//    if ( mGroups != nil ) {
//        NSString *key = [groupId stringByAppendingFormat:@"_%ld", type];
//        return mGroups[key];
//    }
//    return nil;
//}

- (nullable id<HLSVariantStream>)variantStream {
    return mSelectedVariantStream;
}

- (nullable id<HLSRendition>)audioRendition {
    return mSelectedAudioRendition;
}

- (nullable id<HLSRendition>)videoRendition {
    return mSelectedVideoRendition;
}

- (nullable id<HLSRendition>)subtitlesRendition {
    return mSelectedSubtitlesRendition;
}
@end
