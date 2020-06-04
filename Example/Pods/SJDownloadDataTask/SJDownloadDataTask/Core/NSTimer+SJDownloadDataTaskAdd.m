//
//  NSTimer+SJDownloadDataTaskAdd.m
//  SJDownloadDataTask
//
//  Created by BlueDancer on 2019/1/14.
//  Copyright © 2019 畅三江. All rights reserved.
//

#import "NSTimer+SJDownloadDataTaskAdd.h"

@implementation NSTimer (SJDownloadDataTaskAdd)
+ (NSTimer *)DownloadDataTaskAdd_timerWithTimeInterval:(NSTimeInterval)ti
                                                 block:(void(^)(NSTimer *timer))block
                                               repeats:(BOOL)repeats {
    NSTimer *timer = [NSTimer timerWithTimeInterval:ti
                                             target:self
                                           selector:@selector(DownloadDataTaskAdd_exeBlock:)
                                           userInfo:block
                                            repeats:repeats];
    return timer;
}

+ (void)DownloadDataTaskAdd_exeBlock:(NSTimer *)timer {
    void(^block)(NSTimer *timer) = timer.userInfo;
    if ( block ) block(timer);
    else [timer invalidate];
}
@end
