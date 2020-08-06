//
//  MCSResource.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSInterfaces.h"
@class MCSResourceUsageLog, MCSResourcePartialContent;

NS_ASSUME_NONNULL_BEGIN

@interface MCSResource : NSObject<MCSResource> {
    @protected
    NSMutableArray<__kindof MCSResourcePartialContent *> *_m;
    BOOL _isCacheFinished;
    NSString *_name;
}

- (instancetype)initWithName:(NSString *)name;

@property (nonatomic, readonly) MCSResourceType type;

- (id<MCSResourceReader>)readerWithRequest:(NSURLRequest *)request;

@property (nonatomic, strong, readonly) id<MCSConfiguration> configuration;

@property (nonatomic, strong, readonly) MCSResourceUsageLog *log;

@property (nonatomic, readonly) BOOL isCacheFinished;

- (nullable NSURL *)playbackURLForCacheWithURL:(NSURL *)URL;

- (void)prepareForReader;

- (nullable MCSResourcePartialContent *)createContentWithRequest:(NSURLRequest *)request response:(NSHTTPURLResponse *)response;
- (NSString *)filePathOfContent:(MCSResourcePartialContent *)content;
@end

NS_ASSUME_NONNULL_END
