//
//  NSTimer+MCS.m
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/7/20.
//

#import "NSTimer+MCS.h"
#import <objc/message.h>

@implementation NSTimer (MCS)

+ (void)mcs_exeUsingBlock:(NSTimer *)timer {
    if ( timer.mcs_usingBlock != nil ) timer.mcs_usingBlock(timer);
}

+ (NSTimer *)mcs_timerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats {
    return [self mcs_timerWithTimeInterval:interval repeats:repeats usingBlock:nil];
}

+ (NSTimer *)mcs_timerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats usingBlock:(void(^_Nullable)(NSTimer *timer))usingBlock {
    NSTimer *timer = [NSTimer timerWithTimeInterval:interval target:self selector:@selector(mcs_exeUsingBlock:) userInfo:nil repeats:repeats];
    timer.mcs_usingBlock = usingBlock;
    return timer;
}

- (void)setMcs_usingBlock:(void (^_Nullable)(NSTimer * _Nonnull))mcs_usingBlock {
    objc_setAssociatedObject(self, @selector(mcs_usingBlock), mcs_usingBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void (^_Nullable)(NSTimer * _Nonnull))mcs_usingBlock {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)mcs_fire {
    [self setFireDate:[NSDate dateWithTimeIntervalSinceNow:self.timeInterval]];
}

@end
