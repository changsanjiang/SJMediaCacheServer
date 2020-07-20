//
//  NSTimer+MCS.h
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/7/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTimer (MCS)

+ (NSTimer *)mcs_timerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats;
+ (NSTimer *)mcs_timerWithTimeInterval:(NSTimeInterval)interval repeats:(BOOL)repeats usingBlock:(void(^_Nullable)(NSTimer *timer))usingBlock;

@property (nonatomic, copy, nullable) void (^mcs_usingBlock)(NSTimer *timer);

- (void)mcs_fire;

@end

NS_ASSUME_NONNULL_END
