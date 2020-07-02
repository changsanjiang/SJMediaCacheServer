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
@property (nonatomic, copy, readonly, nullable) NSString *tsContentType;
@property (nonatomic, readonly) NSUInteger tsCount;
@property (nonatomic, strong, nullable) MCSHLSParser *parser;

- (NSString *)AESKeyFilePathForAESKeyProxyURL:(NSURL *)URL;
- (NSString *)tsNameForTsProxyURL:(NSURL *)URL;
- (nullable MCSResourcePartialContent *)contentForTsProxyURL:(NSURL *)URL __deprecated;
- (MCSResourcePartialContent *)createContentWithTsProxyURL:(NSURL *)URL tsTotalLength:(NSUInteger)totalLength;
- (NSString *)filePathOfContent:(MCSResourcePartialContent *)content;
- (void)updateTsContentType:(NSString * _Nullable)tsContentType;

#pragma mark -

- (nullable MCSResourcePartialContent *)contentForTsURL:(NSURL *)URL;

- (nullable MCSResourcePartialContent *)contentForAESKeyURL:(NSURL *)URL;
- (MCSResourcePartialContent *)createContentWithAESKeyURL:(NSURL *)URL totalLength:(NSUInteger)totalLength;
@end
NS_ASSUME_NONNULL_END
