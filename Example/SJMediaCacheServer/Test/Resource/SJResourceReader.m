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
- (instancetype)initWithRange:(NSRange)range partialContents:(NSArray<SJResourcePartialContent *> *)contents {
    self = [super init];
    if ( self ) {
        _contents = contents.copy;
        _range = range;
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
@end
