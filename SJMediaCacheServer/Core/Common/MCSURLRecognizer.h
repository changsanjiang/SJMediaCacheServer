//
//  MCSURLRecognizer.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDefines.h"
#import "MCSProxyServer.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSURLRecognizer : NSObject
+ (instancetype)shared;

@property (nonatomic, strong, nullable) MCSProxyServer *server;

@property (nonatomic, copy, nullable) NSString *(^resolveResourceIdentifier)(NSURL *URL);

- (NSURLQueryItem *)encodedURLQueryItemWithUrl:(NSString *)url;

- (NSURL *)proxyURLWithURL:(NSURL *)URL;
- (NSURL *)URLWithProxyURL:(NSURL *)proxyURL;

- (NSString *)resourceNameForURL:(NSURL *)URL;
- (MCSResourceType)resourceTypeForURL:(NSURL *)URL;

- (NSURL *)proxyURLWithTsURI:(NSString *)TsURI;

- (NSString *)fnameWithUrl:(NSString *)url extension:(NSString *)extension;
@end


@interface MCSURLRecognizer (HLS)
- (NSString *)proxyTsURIWithUrl:(NSString *)url inResource:(NSString *)resource;
- (NSString *)proxyAESKeyURIWithUrl:(NSString *)url inResource:(NSString *)resource;
@end

@interface NSString (MCSURLRecognizerExtended)
- (NSString *)stringByAppendingEncodedURLQueryItem:(NSURLQueryItem *)item;
@end
NS_ASSUME_NONNULL_END
