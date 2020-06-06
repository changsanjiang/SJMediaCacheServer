//
//  SJUtils.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/5.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef struct response_content_range {
    NSUInteger start; // `NSNotFound` means undefined
    NSUInteger end;
    NSUInteger totalLength;
} SJResponseContentRange;


FOUNDATION_EXTERN SJResponseContentRange
SJGetResponseContentRange(NSHTTPURLResponse *response);

FOUNDATION_EXTERN NSRange
SJGetResponseNSRange(SJResponseContentRange responseRange);

FOUNDATION_EXTERN NSString *
SJGetResponseServer(NSHTTPURLResponse *response);

FOUNDATION_EXTERN NSString *
SJGetResponseContentType(NSHTTPURLResponse *response);

FOUNDATION_EXPORT NSUInteger
SJGetResponseContentLength(NSHTTPURLResponse *response);

#pragma mark -

typedef struct request_content_range {
    NSUInteger start; // `NSNotFound` means undefined
    NSUInteger end;
} SJRequestContentRange;

FOUNDATION_EXTERN SJRequestContentRange
SJGetRequestContentRange(NSDictionary *requestHeaders);

FOUNDATION_EXTERN NSRange
SJGetRequestNSRange(SJRequestContentRange requestRange);

#pragma mark -

FOUNDATION_EXPORT BOOL
SJNSRangeIsUndefined(NSRange range);

FOUNDATION_EXPORT BOOL
SJNSRangeContains(NSRange main, NSRange sub);
NS_ASSUME_NONNULL_END
