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
+ (nullable NSString *)proxyPlaylistWithAsset:(NSString *)assetName originalPlaylistData:(NSData *)rawData sourceURL:(NSURL *)sourceURL error:(out NSError **)errorPtr;

- (instancetype)initWithProxyPlaylist:(NSString *)playlist;

@property (nonatomic, readonly) NSUInteger allItemsCount;
@property (nonatomic, readonly) NSUInteger segmentsCount;

@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSURIItem>> *allItems;
@property (nonatomic, strong, readonly, nullable) NSArray<id<HLSURIItem>> *segments;
    
- (nullable id<HLSURIItem>)itemAtIndex:(NSUInteger)index;
- (BOOL)isVariantItem:(id<HLSURIItem>)item;
- (nullable NSArray<id<HLSURIItem>> *)renditionsItemsForVariantItem:(id<HLSURIItem>)item;
@end

@protocol HLSURIItem <NSObject>
@property (nonatomic, readonly) MCSDataType type;
@property (nonatomic, copy, readonly) NSString *URI;
@property (nonatomic, copy, readonly, nullable) NSDictionary *HTTPAdditionalHeaders;
@end

//(lldb) po mAllItems
//<__NSArrayI 0x600000c4df50>(
//HLSURIItem:<0x600002130780> { type: 2, URI: mcsproxy/8be8bdccb3192aee88eabbcb5b2fb488/14dcbf185c43dc6f9866777eff4e45a1.key?url=aHR0cDovL2xvY2FsaG9zdC9obHMvZW5jLmtleQ==, HTTPAdditionalHeaders: (null)
// };,
//HLSURIItem:<0x600002130730> { type: 3, URI: mcsproxy/8be8bdccb3192aee88eabbcb5b2fb488/c8262643b25beee941ba7d7683b04cfc.ts?url=aHR0cDovL2xvY2FsaG9zdC9obHMvZmlsZVNlcXVlbmNlMC50cw==, HTTPAdditionalHeaders: (null)
// };,
//HLSURIItem:<0x6000021307d0> { type: 3, URI: mcsproxy/8be8bdccb3192aee88eabbcb5b2fb488/032b10ca182f919f6635738db312e5ac.ts?url=aHR0cDovL2xvY2FsaG9zdC9obHMvZmlsZVNlcXVlbmNlMS50cw==, HTTPAdditionalHeaders: (null)
// };,
//HLSURIItem:<0x600002130820> { type: 3, URI: mcsproxy/8be8bdccb3192aee88eabbcb5b2fb488/7897cdef24288d71fe67ee004a73e82e.ts?url=aHR0cDovL2xvY2FsaG9zdC9obHMvZmlsZVNlcXVlbmNlMi50cw==, HTTPAdditionalHeaders: (null)
// };
//)
NS_ASSUME_NONNULL_END
