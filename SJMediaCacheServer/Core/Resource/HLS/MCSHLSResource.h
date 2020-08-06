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
@property (nonatomic, copy, readonly, nullable) NSString *TsContentType;
@property (nonatomic, readonly) NSUInteger TsCount;
@property (nonatomic, strong, nullable) MCSHLSParser *parser;

- (nullable __kindof MCSResourcePartialContent *)contentForProxyURL:(NSURL *)proxyURL;

- (void)updateTsContentType:(NSString * _Nullable)TsContentType __deprecated;
- (nullable MCSResourcePartialContent *)contentForTsURL:(NSURL *)URL __deprecated;
- (MCSResourcePartialContent *)createContentWithTsURL:(NSURL *)URL totalLength:(NSUInteger)totalLength __deprecated;
@end
NS_ASSUME_NONNULL_END
