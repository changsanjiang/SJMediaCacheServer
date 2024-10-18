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
    HLSItemTypeKey,
    HLSItemTypeSegment,
    HLSItemTypeVariantStream,
    HLSItemTypeRendition,
};

@protocol HLSURIItem <NSObject>
@property (nonatomic, copy, readonly) NSString *URI;
@end

typedef NS_ENUM(NSUInteger, HLSKeyMethod) {
    HLSKeyMethodNone,        // "NONE"
    HLSKeyMethodAES128,      // "AES-128"
    HLSKeyMethodSampleAES    // "SAMPLE-AES"
};

/// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.2.4
///
/// #EXT-X-KEY:METHOD=NONE 这种情况下, 不需要 URI 和 IV, 表示后续的媒体段不加密;
/// #EXT-X-KEY:METHOD=AES-128,URI="https://example.com/key",IV=0x1a2b3c4d5e6f7g8h9i0jklmnopqrst
/// #EXT-X-KEY:METHOD=AES-128,URI="https://example.com/key"
/// #EXT-X-KEY:METHOD=SAMPLE-AES,URI="https://example.com/key",KEYFORMAT="com.apple.streamingkeydelivery",KEYFORMATVERSIONS="1"
/// #EXT-X-KEY:METHOD=SAMPLE-AES,URI="https://drm.example.com/widevine-key",KEYFORMAT="com.widevine.alpha",KEYFORMATVERSIONS="1/2"
@protocol HLSKey <HLSURIItem> // #EXT-X-KEY
@property (nonatomic, readonly) HLSKeyMethod method;                            // 加密方法
@property (nonatomic, copy, readonly, nullable) NSString *IV;                   // 可选的初始化向量
@property (nonatomic, copy, readonly, nullable) NSString *keyFormat;            // 可选的密钥格式
@property (nonatomic, copy, readonly, nullable) NSString *keyFormatVersions;    // 可选的密钥格式版本
@end


/// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.2.1
@protocol HLSSegment <HLSURIItem> // #EXTINF
/// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.2.2
@property (nonatomic, copy, readonly, nullable) NSString *byteRange; // #EXT-X-BYTERANGE
@end


/// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.4.2
@protocol HLSVariantStreamItem <HLSURIItem> // #EXT-X-STREAM-INF
@property (nonatomic, readonly) NSUInteger bandwidth;
@property (nonatomic, copy, readonly) NSString *resolution;
@property (nonatomic, copy, readonly, nullable) NSString *audioGroupID;
@property (nonatomic, copy, readonly, nullable) NSString *videoGroupID;
// other group id "SUBTITLES, CLOSED-CAPTIONS"
@end


/// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.4.1
/// valid strings are AUDIO, VIDEO, SUBTITLES, and CLOSED-CAPTIONS.
typedef NS_ENUM(NSUInteger, HLSRenditionType) {
    HLSRenditionTypeAudio,
    HLSRenditionTypeVideo,
    // other SUBTITLES, CLOSED-CAPTIONS
};
 
/// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.4.1
@protocol HLSRendition <HLSURIItem> // #EXT-X-MEDIA
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly, nullable) NSString *language;
/// If the value is YES, then the client SHOULD play this Rendition of
/// the content in the absence of information from the user indicating
/// a different choice.  This attribute is OPTIONAL.  Its absence
/// indicates an implicit value of NO.
@property (nonatomic, readonly) BOOL isDefault;
@property (nonatomic, readonly) BOOL isAutoSelect;
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
@protocol HLSRenditionGroup <NSObject>
@property (nonatomic, copy, readonly) NSString *groupId;
@property (nonatomic, readonly) HLSRenditionType renditionType;
@property (nonatomic, copy, readonly) NSArray<id<HLSRendition>> *renditions; // HLSRenditionType
@end

@protocol HLSParser <NSObject>
@property (nonatomic, readonly) NSUInteger allItemsCount;
@property (nonatomic, readonly) NSUInteger segmentsCount;

@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSURIItem>> *allItems;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSKey>> *keys;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSSegment>> *segments;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSVariantStreamItem>> *variantStreams;
- (nullable id<HLSRenditionGroup>)mediaGroupBy:(NSString *)groupId mediaType:(HLSRenditionType)mediaType;
@property (nonatomic, strong, readonly, nullable) id<HLSVariantStreamItem> defaultVariantStream;
@end

#pragma mark - mark

@protocol HLSAssetSegment <MCSAssetContent>
@property (nonatomic, readonly) UInt64 totalLength; // segment file totalLength or #EXT-X-BYTERANGE:1544984@1007868
@property (nonatomic, readonly) NSRange byteRange; // segment file {0, totalLength} or #EXT-X-BYTERANGE:1544984@1007868
@end
NS_ASSUME_NONNULL_END
#endif /* HLSAssetDefines_h */
