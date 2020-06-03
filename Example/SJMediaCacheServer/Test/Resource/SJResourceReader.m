//
//  SJResourceReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/3.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourceReader.h"

@interface SJResourceReader ()

@end

@implementation SJResourceReader
- (instancetype)initWithPartialContents:(NSArray<SJResourcePartialContent *> *)contents {
    self = [super init];
    if ( self ) {
        _contents = contents.copy;
    }
    return self;
}

- (void)prepare {
    
}

- (UInt64)contentLength {
    return 0;
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    return nil;
}

- (void)close {
    
}
@end
