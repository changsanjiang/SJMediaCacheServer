//
//  MCSResourceNetworkDataReader.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResourceDefines.h"
#import "MCSResourceResponse.h"
@class MCSVODResourcePartialContent;

NS_ASSUME_NONNULL_BEGIN

@interface MCSResourceNetworkDataReader : NSObject<MCSResourceDataReader>
- (instancetype)initWithURL:(NSURL *)URL requestHeaders:(NSDictionary *)headers range:(NSRange)range;

@property (nonatomic, readonly) NSRange range;

- (void)prepare;
@property (nonatomic, strong, readonly, nullable) NSHTTPURLResponse *response;
@property (nonatomic, readonly) BOOL isDone;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (void)close;

@end

@protocol MCSResourceNetworkDataReaderDelegate <MCSResourceDataReaderDelegate>
- (MCSVODResourcePartialContent *)newPartialContentForReader:(MCSResourceNetworkDataReader *)reader;
- (NSString *)writePathOfPartialContent:(MCSVODResourcePartialContent *)content;
@end

NS_ASSUME_NONNULL_END
