//
//  HLSAsset.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSInterfaces.h"
#import "HLSAssetParser.h"
#import "HLSAssetDefines.h"
#import "MCSReadwrite.h"

NS_ASSUME_NONNULL_BEGIN
@interface HLSAsset : MCSReadwrite<MCSAsset>
@property (nonatomic, readonly) MCSAssetType type;
@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, strong, readonly) id<MCSConfiguration> configuration;
@property (nonatomic, readonly) BOOL isStored;
@property (nonatomic, readonly) float completeness;

@property (nonatomic, copy, nullable) HLSVariantStreamSelectionHandler variantStreamSelectionHandler;
@property (nonatomic, copy, nullable) HLSRenditionSelectionHandler renditionSelectionHandler;
@property (nonatomic, copy, nullable) HLSKeyDecryptionHandler keyDecryptionHandler;


@property (nonatomic, readonly) NSUInteger allItemsCount;
@property (nonatomic, readonly) NSUInteger segmentsCount;
- (nullable __kindof id<HLSItem>)itemAtIndex:(NSUInteger)index;

- (nullable id<MCSAssetReader>)readerWithRequest:(id<MCSRequest>)request networkTaskPriority:(float)networkTaskPriority readDataDecryptor:(NSData *(^_Nullable)(NSURLRequest *request, NSUInteger offset, NSData *data))readDataDecryptor delegate:(nullable id<MCSAssetReaderDelegate>)delegate;

- (nullable id<MCSAssetContent>)getPlaylistContent; // content readwrite is retained, should release after;
- (nullable id<MCSAssetContent>)createPlaylistContentWithOriginalURL:(NSURL *)originalURL currentURL:(NSURL *)currentURL playlist:(NSData *)rawData error:(out NSError **)error; // content readwrite is retained, should release after;

- (nullable id<MCSAssetContent>)getAESKeyContentWithOriginalURL:(NSURL *)originalURL; // content readwrite is retained, should release after;
- (nullable id<MCSAssetContent>)createAESKeyContentWithOriginalURL:(NSURL *)originalURL data:(NSData *)data error:(out NSError **)error; // content readwrite is retained, should release after;

- (nullable id<MCSAssetContent>)getInitializationContentWithOriginalURL:(NSURL *)originalURL byteRange:(NSRange)byteRange; // content readwrite is retained, should release after;
- (nullable id<MCSAssetContent>)createInitializationContentWithOriginalURL:(NSURL *)originalURL response:(id<MCSDownloadResponse>)response data:(NSData *)data error:(out NSError **)error; // content readwrite is retained, should release after;

- (nullable id<MCSAssetContent>)getSubtitlesContentWithOriginalURL:(NSURL *)originalURL; // content readwrite is retained, should release after;
- (nullable id<MCSAssetContent>)createSubtitlesContentWithOriginalURL:(NSURL *)originalURL data:(NSData *)data error:(out NSError **)error; // retained, should release after;

- (nullable id<HLSAssetSegment>)getSegmentContentWithOriginalURL:(NSURL *)originalURL byteRange:(NSRange)byteRange; // content readwrite is retained, should release after;
- (nullable id<MCSAssetContent>)createContentWithDataType:(MCSDataType)dataType response:(id<MCSDownloadResponse>)response error:(NSError **)error; // This method is used only for creating segment content; retained, should release after;

@end

/// ----- master.m3u8
/// #EXTM3U
/// #EXT-X-VERSION:6
/// #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio_group",NAME="English",DEFAULT=YES,AUTOSELECT=YES,LANGUAGE="en",URI="https://example.com/audio/english.m3u8"
/// #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio_group",NAME="Spanish",DEFAULT=NO,AUTOSELECT=YES,LANGUAGE="es",URI="https://example.com/audio/spanish.m3u8"
/// #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subtitles_group",NAME="English",DEFAULT=NO,AUTOSELECT=YES,URI="https://example.com/subtitles/english.vtt"
/// #EXT-X-STREAM-INF:BANDWIDTH=1280000,RESOLUTION=1280x720,AUDIO="audio_group"
/// 720p_output.m3u8
/// #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=854x480,AUDIO="audio_group"
/// 480p_output.m3u8
///
/// ----- variant_stream: 720p_output.m3u8
/// 720p_output.m3u8
/// #EXTM3U
/// #EXT-X-VERSION:6
/// #EXT-X-TARGETDURATION:10
/// #EXT-X-MEDIA-SEQUENCE:0
/// #EXT-X-INDEPENDENT-SEGMENTS
/// #EXTINF:10.0,
/// 720p_segment_000.ts
/// #EXT-X-ENDLIST
///
/// ----- audio_rendition: english.m3u8
/// #EXTM3U
/// #EXT-X-VERSION:6
/// #EXT-X-TARGETDURATION:10
/// #EXT-X-MEDIA-SEQUENCE:0
/// #EXTINF:10.0,
/// english_segment_000.ts
/// #EXT-X-ENDLIST
@interface HLSAsset (VariantStream)
@property (nonatomic, strong, readonly, nullable) HLSAsset *selectedVariantStreamAsset;
@property (nonatomic, strong, readonly, nullable) HLSAsset *selectedAudioRenditionAsset;
@property (nonatomic, strong, readonly, nullable) HLSAsset *selectedVideoRenditionAsset;
/// variantStreamAsset.masterAsset;
/// selectedAudioRenditionAsset.masterAsset;
/// selectedVideoRenditionAsset.masterAsset;
@property (nonatomic, weak, readonly, nullable) HLSAsset *masterAsset;

//@property (nonatomic, readonly) BOOL isVariantStreamAsset;
//@property (nonatomic, readonly) BOOL isAudioRenditionAsset;
//@property (nonatomic, readonly) BOOL isVideoRenditionAsset;
//@property (nonatomic, readonly) BOOL isMasterAsset;
@property (nonatomic, strong, readonly, nullable) id<HLSVariantStream> selectedVariantStream;
@property (nonatomic, strong, readonly, nullable) id<HLSRendition> selectedAudioRendition;
@property (nonatomic, strong, readonly, nullable) id<HLSRendition> selectedVideoRendition;
@property (nonatomic, strong, readonly, nullable) id<HLSRendition> selectedSubtitlesRendition;
@end
NS_ASSUME_NONNULL_END
