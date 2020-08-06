//
//  MCSHLSIndexDataReader.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/10.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResourceDataReader.h"
#import "MCSHLSParser.h"
@protocol MCSResourceResponse;
@class MCSHLSResource;

NS_ASSUME_NONNULL_BEGIN

@interface MCSHLSIndexDataReader : MCSResourceDataReader
- (instancetype)initWithResource:(MCSHLSResource *)resource proxyRequest:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority delegate:(id<MCSResourceDataReaderDelegate>)delegate;

@property (nonatomic, strong, readonly, nullable) MCSHLSParser *parser;

@end
NS_ASSUME_NONNULL_END
