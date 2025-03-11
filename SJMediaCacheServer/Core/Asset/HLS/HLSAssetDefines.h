//
//  HLSAssetDefines.h
//  Pods
//
//  Created by 畅三江 on 2021/7/19.
//

#ifndef HLSAssetDefines_h
#define HLSAssetDefines_h

#import "MCSAssetDefines.h"

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, HLSItemType) {
    HLSItemTypeKey, // #EXT-X-KEY
    HLSItemTypeInitialization, // #EXT-X-MAP
    HLSItemTypeSegment, // #EXTINF
    HLSItemTypeVariantStream, // #EXT-X-STREAM-INF
    HLSItemTypeIFrameStream, // // #EXT-X-I-FRAME-STREAM-INF; ignored;
    HLSItemTypeRendition, // #EXT-X-MEDIA
};

@protocol HLSItem <NSObject>
/// 因为需要代理请求, 所以 Playlist 中我们关注更多的是这些 URI;
///
/// 某些 Tag 无 URI 配置, 例如 CLOSED-CAPTIONS 通常嵌入在视频流中;
@property (nonatomic, copy, readonly, nullable) NSString *URI;
@end

@protocol HLSKey <HLSItem> // #EXT-X-KEY

@end

@protocol HLSInitialization <HLSItem> // #EXT-X-MAP
@property (nonatomic, readonly) NSRange byteRange; // BYTERANGE or { NSNotFound, NSNotFound }; OPTIONAL: specifies byte range for initialization file
@end

@protocol HLSSegment <HLSItem> // #EXTINF
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSRange byteRange; // #EXT-X-BYTERANGE or { NSNotFound, NSNotFound }
@end

@protocol HLSVariantStream <HLSItem> // #EXT-X-STREAM-INF
@property (nonatomic, readonly) NSUInteger bandwidth;               // REQUIRED: BANDWIDTH attribute
@property (nonatomic, readonly) NSUInteger averageBandwidth;        // OPTIONAL: AVERAGE-BANDWIDTH attribute
@property (nonatomic, copy, readonly, nullable) NSString *codecs;   // OPTIONAL: CODECS attribute
@property (nonatomic, copy, readonly, nullable) NSString *resolution; // OPTIONAL: RESOLUTION attribute
@property (nonatomic, copy, readonly, nullable) NSString *frameRate; // OPTIONAL: FRAME-RATE attribute
@property (nonatomic, copy, readonly, nullable) NSString *audioGroupID; // OPTIONAL: AUDIO group ID
@property (nonatomic, copy, readonly, nullable) NSString *videoGroupID; // OPTIONAL: VIDEO group ID
@property (nonatomic, copy, readonly, nullable) NSString *subtitlesGroupID; // OPTIONAL: SUBTITLES group ID
@property (nonatomic, copy, readonly, nullable) NSString *closedCaptionsGroupID; // OPTIONAL: CLOSED-CAPTIONS group ID
@end

// ignored;
@protocol HLSIFrameStream <HLSItem> // #EXT-X-I-FRAME-STREAM-INF
@property (nonatomic, readonly) NSUInteger bandwidth;             // REQUIRED: BANDWIDTH attribute
@property (nonatomic, copy, readonly, nullable) NSString *codecs;   // OPTIONAL: CODECS attribute
@property (nonatomic, copy, readonly, nullable) NSString *resolution; // OPTIONAL: RESOLUTION attribute
@property (nonatomic, copy, readonly, nullable) NSString *videoGroupID; // OPTIONAL: VIDEO group ID
@end

/// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.4.1
/// valid strings are AUDIO, VIDEO, SUBTITLES, and CLOSED-CAPTIONS.
typedef NS_ENUM(NSUInteger, HLSRenditionType) {
    HLSRenditionTypeAudio,
    HLSRenditionTypeVideo,
    HLSRenditionTypeSubtitles,
    HLSRenditionTypeClosedCaptions, // ignored; 通常嵌入在视频流中无需代理;
};
 
/// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.4.1
@protocol HLSRendition <HLSItem> // #EXT-X-MEDIA
@property (nonatomic, readonly) HLSRenditionType renditionType;
@property (nonatomic, copy, readonly) NSString *groupId;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly, nullable) NSString *language;
/// If the value is YES, then the client SHOULD play this Rendition of
/// the content in the absence of information from the user indicating
/// a different choice.  This attribute is OPTIONAL.  Its absence
/// indicates an implicit value of NO.
@property (nonatomic, readonly) BOOL isDefault;
@property (nonatomic, readonly) BOOL isAutoSelect;
@end

@protocol HLSRenditionGroup <NSObject>
@property (nonatomic, copy, readonly) NSString *groupId;
@property (nonatomic, readonly) HLSRenditionType renditionType;
@property (nonatomic, copy, readonly) NSArray<id<HLSRendition>> *renditions; // HLSRenditionType
@end

@protocol HLSParser <NSObject>
@property (nonatomic, readonly) NSUInteger allItemsCount;
@property (nonatomic, readonly) NSUInteger segmentsCount;

@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSItem>> *allItems;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSKey>> *keys;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSInitialization>> *initializations;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSSegment>> *segments;

// In the proxy playlist, the content related to iframe streams will be removed,
// and no proxy content will be generated for it.
//@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSIFrameStream>> *iframeStreams;

/// Represents the selected variant stream. If there are variant streams in the m3u8, only one can be selected.
/// The selection is made through HLSVariantStreamSelectionHandler.
@property (nonatomic, strong, readonly, nullable) id<HLSVariantStream> variantStream;
/// Represents the selected audio rendition. If there are audio renditions in the m3u8, only one can be selected.
/// The selection is made through HLSRenditionSelectionHandler.
@property (nonatomic, strong, readonly, nullable) id<HLSRendition> audioRendition;
/// Represents the selected video rendition. If there are video renditions in the m3u8, only one can be selected.
/// The selection is made through HLSRenditionSelectionHandler.
@property (nonatomic, strong, readonly, nullable) id<HLSRendition> videoRendition;
/// Represents the selected subtitles rendition. If there are subtitles renditions in the m3u8, only one can be selected.
/// The selection is made through HLSRenditionSelectionHandler.
@property (nonatomic, strong, readonly, nullable) id<HLSRendition> subtitlesRendition;
// only one can be selected;
//@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSVariantStream>> *variantStreams;
//- (nullable id<HLSRenditionGroup>)renditionGroupBy:(NSString *)groupId type:(HLSRenditionType)type;

@end

#pragma mark - mark

/// 选一个媒体进行代理
///
/// 变体流 二选一, 选 low 还是 high;
///
/// #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360,CODECS="avc1.4d401e,mp4a.40.2",AUDIO="audio-group"
/// https://example.com/low/index.m3u8
///
/// #EXT-X-STREAM-INF:BANDWIDTH=3000000,AVERAGE-BANDWIDTH=2500000,RESOLUTION=1280x720,FRAME-RATE=60,CODECS="avc1.4d4028,mp4a.40.2",AUDIO="audio-group",SUBTITLES="subs-group"
/// https://example.com/high/index.m3u8
typedef id<HLSVariantStream> _Nullable (^HLSVariantStreamSelectionHandler)(NSArray<id<HLSVariantStream>> *variantStreams, NSURL *originalURL, NSURL *currentURL);

/// AUDIO 二选一
/// #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="en",URI="audio_eng.m3u8"
/// #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Spanish",LANGUAGE="es",URI="audio_spa.m3u8"
///
/// SUBTITLES 二选一
/// #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",URI="subs_eng.m3u8"
/// #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Spanish",LANGUAGE="es",URI="subs_spa.m3u8"
typedef id<HLSRendition> _Nullable (^HLSRenditionSelectionHandler)(HLSRenditionType renditionType, id<HLSRenditionGroup> renditionGroup, NSURL *originalURL, NSURL *currentURL);

#pragma mark - mark

@protocol HLSAssetSegment <MCSAssetContent>
@property (nonatomic, readonly) UInt64 totalLength; // segment file totalLength or #EXT-X-BYTERANGE:1544984@1007868
@property (nonatomic, readonly) NSRange byteRange; // segment file {0, totalLength} or #EXT-X-BYTERANGE:1544984@1007868
@end


typedef NSData * _Nonnull (^HLSKeyDecryptionHandler)(NSData *data, NSURL *originalURL, NSURL *currentURL);
NS_ASSUME_NONNULL_END
#endif /* HLSAssetDefines_h */
