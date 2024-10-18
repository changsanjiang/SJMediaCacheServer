//
//  HLSAssetParser.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDefines.h"
@protocol HLSURIItem;

NS_ASSUME_NONNULL_BEGIN
@interface HLSAssetParser : NSObject
+ (nullable NSString *)proxyPlaylistWithAsset:(NSString *)assetName originalPlaylistData:(NSData *)rawData resourceURL:(NSURL *)resourceURL error:(out NSError **)errorPtr;

- (instancetype)initWithProxyPlaylist:(NSString *)playlist;

@property (nonatomic, readonly) NSUInteger allItemsCount;
@property (nonatomic, readonly) NSUInteger segmentsCount;

@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSURIItem>> *allItems;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSURIItem>> *segments;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSURIItem>> *aesKeys;
    
- (nullable id<HLSURIItem>)itemAtIndex:(NSUInteger)index;
- (BOOL)isVariantStream:(id<HLSURIItem>)item;
- (nullable NSArray<id<HLSURIItem>> *)renditionMediasForVariantItem:(id<HLSURIItem>)item;
@end

typedef NS_ENUM(NSUInteger, HLSItemType) {
    HLSItemTypePlaylist,
    HLSItemTypeAESKey,
    HLSItemTypeVariantStream,
    HLSItemTypeSegment,
};

@protocol HLSURIItem <NSObject>
@property (nonatomic, readonly) MCSDataType type;
@property (nonatomic, copy, readonly) NSString *URI;
@property (nonatomic, copy, readonly, nullable) NSDictionary *HTTPAdditionalHeaders;
@end

@protocol HLSPlaylistItem <HLSURIItem> // #EXT-X-MEDIA

@end

@protocol HLSSegmentItem <HLSURIItem> // #EXTINF
@property (nonatomic, copy, readonly, nullable) NSString *byteRange; // 字节范围，可选，用于 byte-range 请求
@end

@protocol HLSVariantStreamItem <HLSURIItem> // #EXT-X-STREAM-INF
@property (nonatomic, readonly) NSUInteger bandwidth;
@property (nonatomic, copy, readonly) NSString *resolution;
@property (nonatomic, copy, readonly, nullable) NSString *audioGroupID;
@property (nonatomic, copy, readonly, nullable) NSString *videoGroupID;
// other group id "SUBTITLES, CLOSED-CAPTIONS"
@end

/// https://datatracker.ietf.org/doc/html/rfc8216#section-4.3.4.1
/// valid strings are AUDIO, VIDEO, SUBTITLES, and CLOSED-CAPTIONS.
typedef NS_ENUM(NSUInteger, HLSRenditionMediaType) {
    HLSRenditionMediaTypeAudio,
    HLSRenditionMediaTypeVideo,
    // other SUBTITLES, CLOSED-CAPTIONS
};
 
@protocol HLSRenditionMedia <HLSURIItem> // #EXT-X-MEDIA
@property (nonatomic, readonly) BOOL isAutoSelect;
// other NAME, LANGUAGE ...
@end

/// #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="en",URI="audio_eng.m3u8"
/// #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Spanish",LANGUAGE="es",URI="audio_spa.m3u8"
///
/// #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",URI="subs_eng.m3u8"
/// #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="Spanish",LANGUAGE="es",URI="subs_spa.m3u8"
@protocol HLSRenditionMediaGroup <NSObject>
@property (nonatomic, copy, readonly) NSString *groupId;
@property (nonatomic, readonly) HLSRenditionMediaType mediaType;
@property (nonatomic, copy, readonly) NSArray<id<HLSRenditionMedia>> *renditions; // Renditions: AUDIO, VIDEO, SUBTITLES, and CLOSED-CAPTIONS
@end

@protocol HLSParser <NSObject>
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSURIItem>> *allItems;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSURIItem>> *aesKeys;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSSegmentItem>> *segments;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSVariantStreamItem>> *variantStreams;
- (nullable id<HLSRenditionMediaGroup>)mediaGroupBy:(NSString *)groupId;
//- (nullable id<HLSRenditionMediaGroup>)mediaGroupBy:(NSString *)groupId mediaType:(HLSRenditionMediaType)mediaType;
@end
NS_ASSUME_NONNULL_END
