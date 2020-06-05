//
//  SJResourceReader.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJMediaCacheServerDefines.h"
#import "SJResourceDefines.h"
#import "SJDataRequest.h"
#import "SJResourceResponse.h"
@class SJResource;

NS_ASSUME_NONNULL_BEGIN

@interface SJResourceReader : NSObject<SJResourceReader>
- (instancetype)initWithResource:(__weak SJResource *)resource request:(SJDataRequest *)request;

@property (nonatomic, weak, nullable) id<SJResourceReaderDelegate> delegate;

- (void)prepare;
@property (nonatomic, strong, readonly, nullable) id<SJResourceResponse> response;
@property (nonatomic, readonly) NSUInteger offset;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
@property (nonatomic, readonly) BOOL isPrepared;
@property (nonatomic, readonly) BOOL isReadingEndOfData;
- (void)close;
@end

NS_ASSUME_NONNULL_END
