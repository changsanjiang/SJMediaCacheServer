//
//  LocalFileAsset.h
//  SJMediaCacheServer
//
//  Created by db on 2025/4/17.
//

#import "MCSInterfaces.h"
#import "MCSReadwrite.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocalFileAsset : MCSReadwrite<MCSAsset>
- (instancetype)initWithName:(NSString *)name;

@property (nonatomic, readonly) MCSAssetType type;

- (void)prepare;
- (nullable id<MCSAssetReader>)readerWithRequest:(id<MCSRequest>)request networkTaskPriority:(float)networkTaskPriority readDataDecryptor:(NSData *(^_Nullable)(NSURLRequest *request, NSUInteger offset, NSData *data))readDataDecryptor delegate:(nullable id<MCSAssetReaderDelegate>)delegate;

- (id<MCSAssetContent>)getContentWithRequest:(id<MCSRequest>)request;
@end

NS_ASSUME_NONNULL_END
