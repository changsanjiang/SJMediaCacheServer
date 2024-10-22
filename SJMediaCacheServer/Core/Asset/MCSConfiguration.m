//
//  MCSConfiguration.m
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/7/6.
//

#import "MCSConfiguration.h"

@interface MCSConfiguration () {
    NSMutableDictionary <NSNumber *, NSMutableDictionary<NSString *, NSString *> *> *_map;
}
@end

@implementation MCSConfiguration
- (void)setValue:(nullable NSString *)value forHTTPAdditionalHeaderField:(NSString *)HTTPHeaderField ofType:(MCSDataType)type {
    BOOL fallThrough = NO;
    switch ( (MCSDataType)(type & MCSDataTypeHLSMask) ) {
        case MCSDataTypeHLSMask:
        case MCSDataTypeFILEMask:
        case MCSDataTypeFILE:
            break;
        case MCSDataTypeHLS: {
            [self _setValue:value forHTTPAdditionalHeaderField:HTTPHeaderField ofType:MCSDataTypeHLS fallThrough:fallThrough];
            fallThrough = YES;
        }
        case MCSDataTypeHLSPlaylist: {
            [self _setValue:value forHTTPAdditionalHeaderField:HTTPHeaderField ofType:MCSDataTypeHLSPlaylist fallThrough:fallThrough];
            if ( !fallThrough ) break;
        }
        case MCSDataTypeHLSAESKey: {
            [self _setValue:value forHTTPAdditionalHeaderField:HTTPHeaderField ofType:MCSDataTypeHLSAESKey fallThrough:fallThrough];
            if ( !fallThrough ) break;
        }
        case MCSDataTypeHLSSegment: {
            [self _setValue:value forHTTPAdditionalHeaderField:HTTPHeaderField ofType:MCSDataTypeHLSSegment fallThrough:fallThrough];
            if ( !fallThrough ) break;
        }
        case MCSDataTypeHLSSubtitles: {
            [self _setValue:value forHTTPAdditionalHeaderField:HTTPHeaderField ofType:MCSDataTypeHLSSubtitles fallThrough:fallThrough];
            if ( !fallThrough ) break;
        }
    }
    
    switch ( (MCSDataType)(type & MCSDataTypeFILEMask) ) {
        case MCSDataTypeHLSMask:
        case MCSDataTypeHLSPlaylist:
        case MCSDataTypeHLSAESKey:
        case MCSDataTypeHLSSegment:
        case MCSDataTypeHLSSubtitles:
        case MCSDataTypeHLS:
        case MCSDataTypeFILEMask:
            break;
        case MCSDataTypeFILE: {
            [self _setValue:value forHTTPAdditionalHeaderField:HTTPHeaderField ofType:MCSDataTypeFILE fallThrough:fallThrough];
            break;
        }
    }
}

- (nullable NSDictionary<NSString *, NSString *> *)HTTPAdditionalHeadersForDataRequestsOfType:(MCSDataType)type {
    @synchronized (self) {
        return _map[@(type)];
    }
}

- (void)_setValue:(nullable NSString *)value forHTTPAdditionalHeaderField:(NSString *)HTTPHeaderField ofType:(MCSDataType)type fallThrough:(BOOL)fallThrough {
    @synchronized (self) {
        if ( _map == nil ) _map = NSMutableDictionary.dictionary;

        NSNumber *key = @(type);
        if ( _map[key][HTTPHeaderField] == nil || !fallThrough ) {
            if ( _map[key] == nil ) _map[key] = NSMutableDictionary.dictionary;
            _map[key][HTTPHeaderField] = value;
        }
    }
}

@end
