//
//  NSTimer+SJDownloadDataTaskAdd.h
//  SJDownloadDataTask
//
//  Created by BlueDancer on 2019/1/14.
//  Copyright © 2019 畅三江. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTimer (SJDownloadDataTaskAdd)
+ (NSTimer *)DownloadDataTaskAdd_timerWithTimeInterval:(NSTimeInterval)ti
                                                 block:(void(^)(NSTimer *timer))block
                                               repeats:(BOOL)repeats;
@end

NS_ASSUME_NONNULL_END
