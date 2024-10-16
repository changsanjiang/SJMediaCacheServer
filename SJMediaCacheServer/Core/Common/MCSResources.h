//
//  MCSResources.h
//  SJMediaCacheServer
//
//  Created by db on 2024/10/16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MCSResources : NSObject

@property (nonatomic, readonly, class) NSBundle *bundle;

+ (NSString *)filePathWithFilename:(NSString *)filename;

@end

NS_ASSUME_NONNULL_END
