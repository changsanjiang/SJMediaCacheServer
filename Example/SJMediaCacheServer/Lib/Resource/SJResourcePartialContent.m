//
//  SJResourcePartialContent.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourcePartialContent.h"

@implementation SJResourcePartialContent
- (instancetype)initWithName:(NSString *)name offset:(NSUInteger)offset {
    return [self initWithName:name offset:offset length:0];
}

- (instancetype)initWithName:(NSString *)name offset:(NSUInteger)offset length:(NSUInteger)length {
    self = [super init];
    if ( self ) {
        _name = name;
        _offset = offset;
        _length = length;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"SJResourcePartialContent: <%p> { name: %@, offset: %lu, length: %lu};", self, _name, _offset, self.length];
}
@end
