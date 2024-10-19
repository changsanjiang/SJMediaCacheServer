//
//  NSArray+MCS.h
//  SJMediaCacheServer
//
//  Created by db on 2024/10/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSArray<ObjectType> (MCS)
- (nullable ObjectType)mcs_firstOrNull:(BOOL (NS_NOESCAPE ^)(ObjectType obj))block;
@end

NS_ASSUME_NONNULL_END
