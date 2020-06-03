//
//  SJResource.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResource.h"

@interface SJResourceManager : NSObject
+ (instancetype)shared;

- (SJResource *)resourceWithURL:(NSURL *)URL;
@end

@implementation SJResourceManager
+ (instancetype)shared {
    static id obj = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[self alloc] init];
    });
    return obj;
}

- (SJResource *)resourceWithURL:(NSURL *)URL {
    return nil;;
}
@end


@implementation SJResource
+ (instancetype)resourceWithURL:(NSURL *)URL {
    return [SJResourceManager.shared resourceWithURL:URL];
}

- (id<SJResourceReader>)readDataWithRequest:(id<SJDataRequest>)request {
    return nil;
}
@end
