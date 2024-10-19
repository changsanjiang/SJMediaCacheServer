//
//  NSArray+MCS.m
//  SJMediaCacheServer
//
//  Created by db on 2024/10/19.
//

#import "NSArray+MCS.h"

@implementation NSArray (MCS)
- (nullable id)mcs_firstOrNull:(BOOL(NS_NOESCAPE ^)(id obj))block {
    __block id retv = nil;
    [self enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ( block(obj) ) {
            retv = obj;
            *stop = YES;
        }
    }];
    return retv;
}
@end
