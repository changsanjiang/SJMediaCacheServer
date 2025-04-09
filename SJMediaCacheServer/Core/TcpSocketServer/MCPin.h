//
//  MCPin.h
//  SJMediaCacheServer
//
//  Created by db on 2025/3/10.
//

#import <Foundation/Foundation.h>
@class MCHttpRequest;

NS_ASSUME_NONNULL_BEGIN

@interface MCPin : NSObject
+ (BOOL)isPinReq:(MCHttpRequest *)req;

// @param failureHandler 失败回调; 失败后会自动停止pin, 如需继续 pin 需要重新调用 start;
- (instancetype)initWithInterval:(NSTimeInterval)interval failureHandler:(void(^)(void))failureHandler;

- (void)startWithPort:(uint16_t)port;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
