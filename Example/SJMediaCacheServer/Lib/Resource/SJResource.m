//
//  SJResource.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResource.h"
#import "SJResourcePartialContent.h"
#import "SJResourceManager.h"

@interface SJResource ()
@property (nonatomic, copy) NSString *path;
@end

@implementation SJResource
+ (instancetype)resourceWithURL:(NSURL *)URL {
    return [SJResourceManager.shared resourceWithURL:URL];
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if ( self ) {
        _path = path.copy;
    }
    return self;
}

- (id<SJResourceReader>)readDataWithRequest:(SJDataRequest *)request {
    return nil;
}

- (NSString *)filePathWithContent:(SJResourcePartialContent *)content {
    return nil;
}

- (SJResourcePartialContent *)newContentWithOffset:(UInt64)offset {
    return nil;
}
@end
