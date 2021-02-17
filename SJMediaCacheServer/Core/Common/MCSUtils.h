//
//  MCSUtils.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/8.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN BOOL
MCSRequestIsRangeRequest(NSURLRequest *request);

typedef struct response_content_range {
    NSUInteger start; // `NSNotFound` means undefined
    NSUInteger end;
    NSUInteger totalLength;
} MCSResponseContentRange;

FOUNDATION_EXTERN MCSResponseContentRange
MCSResponseGetContentRange(NSHTTPURLResponse *response);

FOUNDATION_EXTERN NSRange
MCSResponseRange(MCSResponseContentRange range);

FOUNDATION_EXTERN NSString *
MCSResponseGetServer(NSHTTPURLResponse *response);

FOUNDATION_EXTERN NSString *
MCSResponseGetContentType(NSHTTPURLResponse *response);

FOUNDATION_EXPORT NSUInteger
MCSResponseGetContentLength(NSHTTPURLResponse *response);

FOUNDATION_EXTERN MCSResponseContentRange const MCSResponseContentRangeUndefined;

FOUNDATION_EXPORT BOOL
MCSResponseRangeIsUndefined(MCSResponseContentRange range);

#pragma mark -

typedef struct request_content_range {
    NSUInteger start; // `NSNotFound` means undefined
    NSUInteger end;
} MCSRequestContentRange;

FOUNDATION_EXTERN MCSRequestContentRange
MCSRequestGetContentRange(NSDictionary *requestHeaders);

FOUNDATION_EXTERN NSRange
MCSRequestRange(MCSRequestContentRange range);

FOUNDATION_EXTERN MCSRequestContentRange const MCSRequestContentRangeUndefined;

FOUNDATION_EXPORT BOOL
MCSRequestRangeIsUndefined(MCSRequestContentRange range);

#pragma mark -

FOUNDATION_EXPORT BOOL
MCSNSRangeIsUndefined(NSRange range);

FOUNDATION_EXPORT BOOL
MCSNSRangeContains(NSRange main, NSRange sub);

FOUNDATION_EXPORT NSString *_Nullable
MCSSuggestedFilePathExtension(NSHTTPURLResponse *response);

#ifdef DEBUG
FOUNDATION_EXPORT uint64_t
MCSStartTime(void);

FOUNDATION_EXPORT NSTimeInterval
MCSEndTime(uint64_t elapsed_time);

#else
#define MCSStartTime()
#define MCSEndTime(...)
#endif
NS_ASSUME_NONNULL_END
