//
//  HLSAssetParser.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "HLSAssetDefines.h"

NS_ASSUME_NONNULL_BEGIN
@interface HLSAssetParser : NSObject<HLSParser>
+ (nullable NSString *)proxyPlaylistWithAsset:(NSString *)assetName 
                                  originalURL:(NSURL *)originalURL
                                   currentURL:(NSURL *)currentURL
                                     playlist:(NSData *)rawData
                variantStreamSelectionHandler:(nullable HLSVariantStreamSelectionHandler)variantStreamSelectionHandler
                    renditionSelectionHandler:(nullable HLSRenditionSelectionHandler)renditionSelectionHandler
                                        error:(out NSError **)errorPtr;

- (instancetype)initWithProxyPlaylist:(NSString *)playlist;

@property (nonatomic, readonly) NSUInteger allItemsCount;
@property (nonatomic, readonly) NSUInteger segmentsCount;

@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSItem>> *allItems;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSKey>> *keys;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSSegment>> *segments;

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
//- (nullable id<HLSRenditionGroup>)renditionGroupBy:(NSString *)groupId type:(HLSRenditionType)type;@end

// In the proxy playlist, the content related to iframe streams will be removed,
// and no proxy content will be generated for it.
//@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSIFrameStream>> *iframeStreams;
@end
NS_ASSUME_NONNULL_END
