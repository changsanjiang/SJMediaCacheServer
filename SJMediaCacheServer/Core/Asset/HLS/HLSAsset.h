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
@property (nonatomic, strong, readonly, nullable) HLSAssetParser *parser;
@property (nonatomic, readonly) BOOL isStored;

@property (nonatomic, copy, nullable) HLSVariantStreamSelectionHandler variantStreamSelectionHandler;
@property (nonatomic, copy, nullable) HLSRenditionSelectionHandler renditionSelectionHandler;

@property (nonatomic, readonly) NSUInteger tsCount;
- (nullable NSArray<id<HLSAssetSegment>> *)TsContents;

- (nullable id<MCSAssetReader>)readerWithRequest:(id<MCSRequest>)request networkTaskPriority:(float)networkTaskPriority readDataDecoder:(NSData *(^_Nullable)(NSURLRequest *request, NSUInteger offset, NSData *data))readDataDecoder delegate:(nullable id<MCSAssetReaderDelegate>)delegate;

- (nullable id<MCSAssetContent>)getPlaylistContent; // retained, should release after;
- (nullable id<MCSAssetContent>)createPlaylistContentWithOriginalURL:(NSURL *)originalURL currentURL:(NSURL *)currentURL playlist:(NSData *)rawData error:(out NSError **)error; // retained, should release after;

- (nullable id<MCSAssetContent>)getAESKeyContentWithOriginalURL:(NSURL *)originalURL; // retained, should release after;
- (nullable id<MCSAssetContent>)createAESKeyContentWithOriginalURL:(NSURL *)originalURL data:(NSData *)data error:(out NSError **)error; // retained, should release after;

- (nullable id<HLSAssetSegment>)getSegmentContentWithOriginalURL:(NSURL *)originalURL byteRange:(NSRange)byteRange; // retained, should release after;
- (nullable id<MCSAssetContent>)createContentReadwriteWithDataType:(MCSDataType)dataType response:(id<MCSDownloadResponse>)response; // This method is used only for creating segment content; retained, should release after;

@end
NS_ASSUME_NONNULL_END
