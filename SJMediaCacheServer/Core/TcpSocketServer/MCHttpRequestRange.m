//
//  MCHttpRequestRange.m
//  SJMediaCacheServer
//
//  Created by 畅三江 on 2025/3/9.
//

#import "MCHttpRequestRange.h"
#import "MCSError.h"

@interface MCHttpRequestRange ()
- (instancetype)initWithRangeStart:(nullable NSString *)rangeStart
                          rangeEnd:(nullable NSString *)rangeEnd
                      suffixLength:(nullable NSString *)suffixLength;
@end

@implementation MCHttpRequestRange
+ (nullable instancetype)parseRequestRangeWithHeader:(NSString *)rangeHeader error:(NSError **)errorPtr {
    /** https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Range#syntax
     Range: <unit>=<range-start>-
     Range: <unit>=<range-start>-<range-end>
     Range: <unit>=<range-start>-<range-end>, <range-start>-<range-end>, …  // @note: Multi-range requests are not supported;
     Range: <unit>=-<suffix-length>
     * */
    if ( ![rangeHeader hasPrefix:@"bytes="] ) {
        if ( errorPtr ) {
            *errorPtr = [NSError mcs_errorWithCode:MCSInvalidParameterError userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unsupported Range unit '%@', Only 'bytes' unit is supported.", rangeHeader]
            }];
        }
        return nil;
    }
    
    if ( [rangeHeader containsString:@","] ) {
        if ( errorPtr ) {
            *errorPtr = [NSError mcs_errorWithCode:MCSInvalidParameterError userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Multi-range requests '%@' are not supported, Only single-range requests are allowed.", rangeHeader]
            }];
        }
        return nil;
    }
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"bytes=(?<f>\\d+)?-(?<s>\\d+)?" options:kNilOptions error:NULL];
    NSArray<NSTextCheckingResult *> *results = [regex matchesInString:rangeHeader options:kNilOptions range:NSMakeRange(0, rangeHeader.length)];
    if ( results.count == 0 ) {
        if ( errorPtr ) {
            *errorPtr = [NSError mcs_errorWithCode:MCSInvalidParameterError userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Invalid Range format '%@', Expected format: bytes=<range-start>-<range-end>'.", rangeHeader]
            }];
        }
        return nil;
    }
    
    NSTextCheckingResult *result = [results firstObject];
    NSRange firstRange = [result rangeWithName:@"f"];
    NSRange secondRange = [result rangeWithName:@"s"];
    NSString *first = firstRange.location != NSNotFound ? [rangeHeader substringWithRange:firstRange] : nil;
    NSString *second = secondRange.location != NSNotFound ? [rangeHeader substringWithRange:secondRange] : nil;
    if ( first == nil && second == nil ) {
        if ( errorPtr ) {
            *errorPtr = [NSError mcs_errorWithCode:MCSInvalidParameterError userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Invalid Range format '%@', At least one of range-start or range-end should be specified.", rangeHeader]
            }];
        }
        return nil;
    }
    
    NSString *rangeStart = first;
    NSString *rangeEnd = first != nil && second != nil ? second : nil;
    NSString *suffixLength = first == nil && second != nil ? second : nil;
    
    if ( rangeStart && rangeEnd ) {
        NSInteger rangeStartValue = [rangeStart integerValue];
        NSInteger rangeEndValue = [rangeEnd integerValue];
        if ( rangeStartValue > rangeEndValue ) {
            if ( errorPtr ) {
                *errorPtr = [NSError mcs_errorWithCode:MCSInvalidParameterError userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Invalid Range '%@': rangeStart cannot be greater than rangeEnd.", rangeHeader]
                }];
            }
            return nil;
        }
    }
    return [MCHttpRequestRange.alloc initWithRangeStart:rangeStart rangeEnd:rangeEnd suffixLength:suffixLength];
}

- (instancetype)initWithRangeStart:(nullable NSString *)rangeStart
                          rangeEnd:(nullable NSString *)rangeEnd
                      suffixLength:(nullable NSString *)suffixLength {
    self = [super init];
    _rangeStart = rangeStart;
    _rangeEnd = rangeEnd;
    _suffixLength = suffixLength;
    return self;
}

- (NSString *)toRangeHeader {
    if ( _suffixLength != nil ) {
        return [NSString stringWithFormat:@"bytes=-%@", _suffixLength];
    }
    
    if ( _rangeStart != nil && _rangeEnd != nil ) {
        return [NSString stringWithFormat:@"bytes=%@-%@", _rangeStart, _rangeEnd];
    }
    
    return [NSString stringWithFormat:@"bytes=%@", _rangeStart];
}
@end
