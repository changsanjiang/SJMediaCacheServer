//
//  SJResourceNetworkDataReader.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceDefines.h"
#import "SJResourceResponse.h"
@class SJResourcePartialContent;

NS_ASSUME_NONNULL_BEGIN

@interface SJResourceNetworkDataReader : NSObject<SJResourceDataReader>
- (instancetype)initWithURL:(NSURL *)URL requestHeaders:(NSDictionary *)headers range:(NSRange)range;
- (void)setDelegate:(id<SJResourceDataReaderDelegate>)delegate delegateQueue:(dispatch_queue_t)queue;

@property (nonatomic, readonly) NSRange range;

- (void)prepare;
@property (nonatomic, strong, readonly, nullable) NSHTTPURLResponse *response;
@property (nonatomic, readonly) NSUInteger offset;
@property (nonatomic, readonly) BOOL isDone;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (void)close;

@end

@protocol SJResourceNetworkDataReaderDelegate <SJResourceDataReaderDelegate>
- (SJResourcePartialContent *)newPartialContentForReader:(SJResourceNetworkDataReader *)reader;
- (NSString *)savePathOfPartialContent:(SJResourcePartialContent *)content;
@end

NS_ASSUME_NONNULL_END
