//
//  HLSAssetParser.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "HLSAssetDefines.h"

NS_ASSUME_NONNULL_BEGIN
@interface HLSAssetParser : NSObject
+ (nullable NSString *)proxyPlaylistWithAsset:(NSString *)assetName originalPlaylistData:(NSData *)rawData resourceURL:(NSURL *)resourceURL error:(out NSError **)errorPtr;

- (instancetype)initWithProxyPlaylist:(NSString *)playlist;

@property (nonatomic, readonly) NSUInteger allItemsCount;
@property (nonatomic, readonly) NSUInteger segmentsCount;

@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSURIItem>> *allItems;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSKey>> *keys;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSSegment>> *segments;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSVariantStreamItem>> *variantStreams;
- (nullable id<HLSRenditionGroup>)mediaGroupBy:(NSString *)groupId mediaType:(HLSRenditionType)mediaType;
@property (nonatomic, strong, readonly, nullable) id<HLSVariantStreamItem> defaultVariantStream;
@end
NS_ASSUME_NONNULL_END
