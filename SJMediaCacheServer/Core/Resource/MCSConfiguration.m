//
//  MCSConfiguration.m
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/7/6.
//

#import "MCSConfiguration.h"

@interface MCSConfiguration ()<NSLocking> {
    dispatch_semaphore_t _semaphore;
    NSMutableDictionary <NSNumber *, NSMutableDictionary *> *_map;
}
@end

@implementation MCSConfiguration
- (instancetype)init {
    self = [super init];
    if ( self ) {
        _semaphore = dispatch_semaphore_create(1);
    }
    return self;
}

- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(NSString *)HTTPHeaderField ofType:(MCSDataType)type {
    [self lock];
    if ( _map == nil ) _map = NSMutableDictionary.dictionary;
    
    NSNumber *key = @(type);
    if ( _map[key] == nil ) _map[key] = NSMutableDictionary.dictionary;

    _map[key][HTTPHeaderField] = value;
    [self unlock];
}

- (nullable NSDictionary *)HTTPAdditionalHeadersForResourceDataRequestOfType:(MCSDataType)type {
    [self lock];
    @try {
        return _map[@(type)];
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

#pragma mark -

- (void)lock {
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
}

- (void)unlock {
    dispatch_semaphore_signal(_semaphore);
}
@end
