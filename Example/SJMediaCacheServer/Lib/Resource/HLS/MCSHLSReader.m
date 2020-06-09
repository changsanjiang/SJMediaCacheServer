//
//  MCSHLSReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSReader.h"
#import "MCSHLSResource.h"

@interface MCSHLSReader ()

@end

@implementation MCSHLSReader
- (instancetype)initWithResource:(__weak MCSHLSResource *)resource request:(NSURLRequest *)request {
    self = [super init];
    if ( self ) {
        
    }
    return self;
}

- (void)prepare {
    
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    return nil;
}

- (void)close {
    
}

//@property (nonatomic, strong, readonly, nullable) id<MCSResourceResponse> response;
//@property (nonatomic, readonly) NSUInteger offset;
//- (nullable NSData *)readDataOfLength:(NSUInteger)length;
//@property (nonatomic, readonly) BOOL isPrepared;
//@property (nonatomic, readonly) BOOL isReadingEndOfData;
//@property (nonatomic, readonly) BOOL isClosed;
//- (void)close;
@end
