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
    self = [super init];
    if ( self ) {
        _name = name;
        _offset = offset;
    }
    return self;
}
@end
