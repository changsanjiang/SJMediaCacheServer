//
//  NSURL+MCS.h
//  SJMediaCacheServer
//
//  Created by db on 2024/10/17.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURL (MCS)
- (NSURL *)mcs_URLByAppendingPathComponent:(NSString *)pathComponent;
- (NSURL *)mcs_URLByRemovingLastPathComponentAndQuery;
@end

NS_ASSUME_NONNULL_END
