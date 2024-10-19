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
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSVariantStream>> *variantStreams;
- (nullable id<HLSRenditionGroup>)renditionGroupBy:(NSString *)groupId type:(HLSRenditionType)type;
@end
NS_ASSUME_NONNULL_END
