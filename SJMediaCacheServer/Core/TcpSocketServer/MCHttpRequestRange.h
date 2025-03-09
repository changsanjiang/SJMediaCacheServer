//
//  MCHttpRequestRange.h
//  SJMediaCacheServer
//
//  Created by 畅三江 on 2025/3/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/**
 * - https://datatracker.ietf.org/doc/html/rfc9110#name-range-requests
 * - https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Range#syntax
 Range: <unit>=<range-start>-
 Range: <unit>=<range-start>-<range-end>
 Range: <unit>=<range-start>-<range-end>, <range-start>-<range-end>, …  // @note: Multi-range requests are not supported;
 Range: <unit>=-<suffix-length>
 * */
@interface MCHttpRequestRange : NSObject
+ (nullable instancetype)parseRequestRangeWithHeader:(NSString *)rangeHeader error:(NSError **)error;
@property (nonatomic, strong, readonly, nullable) NSString *rangeStart;
@property (nonatomic, strong, readonly, nullable) NSString *rangeEnd;
@property (nonatomic, strong, readonly, nullable) NSString *suffixLength;

/// 'bytes=xxx-xxx'
- (NSString *)toRangeHeader;
@end
NS_ASSUME_NONNULL_END
