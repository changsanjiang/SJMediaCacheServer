//
//  MCSContents.h
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/7/7.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MCSContents : NSObject
 
+ (void)request:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority willPerformHTTPRedirection:(void(^_Nullable)(NSURLRequest *newRequest))block completion:(void(^)(NSData *_Nullable data, NSError *_Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
