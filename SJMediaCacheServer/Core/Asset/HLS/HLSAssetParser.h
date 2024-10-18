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
- (BOOL)isVariantItem:(id<HLSURIItem>)item;
- (nullable NSArray<id<HLSURIItem>> *)renditionsItemsForVariantItem:(id<HLSURIItem>)item;
@end

@protocol HLSURIItem <NSObject>
@property (nonatomic, readonly) MCSDataType type;
@property (nonatomic, copy, readonly) NSString *URI;
@property (nonatomic, copy, readonly, nullable) NSDictionary *HTTPAdditionalHeaders;
@end
NS_ASSUME_NONNULL_END
