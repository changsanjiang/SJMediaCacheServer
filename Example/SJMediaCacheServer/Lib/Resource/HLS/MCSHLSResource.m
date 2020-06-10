//
//  MCSHLSResource.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSResource.h"
#import "MCSResourceManager.h"
#import "MCSHLSReader.h"
#import "MCSHLSParser.h"
#import "MCSResourceSubclass.h"

@interface MCSHLSResource ()
@property (nonatomic, strong, nullable) MCSHLSParser *parser;
@end

@implementation MCSHLSResource
- (MCSResourceType)type {
    return MCSResourceTypeHLS;
}

- (id<MCSResourceReader>)readerWithRequest:(NSURLRequest *)request {
    return [MCSHLSReader.alloc initWithResource:self request:request];
}

- (id<MCSResourcePrefetcher>)prefetcherWithRequest:(NSURLRequest *)request {
    return nil;
}

@synthesize parser = _parser;
- (void)setParser:(MCSHLSParser *)parser {
    [self lock];
    _parser = parser;
    [self unlock];
}

- (MCSHLSParser *)parser {
    [self lock];
    @try {
        return _parser;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}
@end
