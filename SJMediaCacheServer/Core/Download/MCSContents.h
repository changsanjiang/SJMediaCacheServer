//
//  MCSContents.h
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/7/7.
//

#import <Foundation/Foundation.h>
#import "MCSInterfaces.h"

NS_ASSUME_NONNULL_BEGIN

@interface MCSContents : NSObject
 
+ (id<MCSDownloadTask>)request:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority completion:(void(^)(id<MCSDownloadTask> task, NSData *_Nullable data, NSError *_Nullable error))completionHandler;

@end

NS_ASSUME_NONNULL_END
