//
//  MCHttpResponse.h
//  SJMediaCacheServer
//
//  Created by 畅三江 on 2025/3/9.
//

#import <Foundation/Foundation.h>
@class MCTcpSocketConnection;

NS_ASSUME_NONNULL_BEGIN

@interface MCHttpResponse : NSObject

+ (void)processConnection:(MCTcpSocketConnection *)connection;

@end

NS_ASSUME_NONNULL_END
