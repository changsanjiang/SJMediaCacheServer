//
//  MCSHLSResource+MCSPrivate.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSResource.h"
#import "MCSHLSParser.h"
#import "MCSResourceSubclass.h"
@class MCSResourcePartialContent;

NS_ASSUME_NONNULL_BEGIN

@interface MCSHLSResource (MCSPrivate)

@property (nonatomic, copy, nullable) NSString *tsContentType;

@property (nonatomic, strong, nullable) MCSHLSParser *parser;

@property (nonatomic, strong, readonly, nullable) NSMutableArray<MCSResourcePartialContent *> *contents;

- (NSString *)tsNameForTsProxyURL:(NSURL *)URL;
- (nullable MCSResourcePartialContent *)contentForTsProxyURL:(NSURL *)URL;
- (MCSResourcePartialContent *)createContentWithTsProxyURL:(NSURL *)URL tsTotalLength:(NSUInteger)totalLength;
- (NSString *)filePathOfContent:(MCSResourcePartialContent *)content;
@end

NS_ASSUME_NONNULL_END
