//
//  MCSHLSTSDataReader.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/10.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSDataReader.h"
#import "MCSHLSParser.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSHLSTSDataReader : NSObject<MCSHLSDataReader>

- (instancetype)initWithRequest:(NSURLRequest *)request parser:(MCSHLSParser *)parser;

- (void)prepare;
@property (nonatomic, readonly) BOOL isDone;
@property (nonatomic, strong, readonly, nullable) id<MCSResourceResponse> response;
- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (void)close;

@end

NS_ASSUME_NONNULL_END
