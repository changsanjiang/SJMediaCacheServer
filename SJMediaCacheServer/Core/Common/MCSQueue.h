//
//  MCSQueue.h
//  Pods
//
//  Created by 畅三江 on 2020/7/14.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT dispatch_queue_t
MCSResourceQueue(void);

FOUNDATION_EXPORT dispatch_queue_t
MCSPrefetcherQueue(void);

FOUNDATION_EXPORT dispatch_queue_t
MCSReaderQueue(void);

FOUNDATION_EXPORT dispatch_queue_t
MCSDownloadQueue(void);

FOUNDATION_EXPORT dispatch_queue_t
MCSDelegateQueue(void);

FOUNDATION_EXPORT dispatch_queue_t
MCSDataReaderQueue(void);

NS_ASSUME_NONNULL_END
