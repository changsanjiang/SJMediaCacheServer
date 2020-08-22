//
//  MCSHLSResource.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResourceSubclass.h"
#import "MCSHLSParser.h"

NS_ASSUME_NONNULL_BEGIN
@interface MCSHLSResource : MCSResource
@property (nonatomic, strong, readonly, nullable) MCSHLSParser *parser;

- (nullable __kindof MCSResourcePartialContent *)partialContentForFileDataReaderWithProxyURL:(NSURL *)proxyURL;
- (void)parseDidFinish:(MCSHLSParser *)parser;
@end
NS_ASSUME_NONNULL_END
