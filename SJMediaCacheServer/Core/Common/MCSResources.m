//
//  MCSResources.m
//  SJMediaCacheServer
//
//  Created by db on 2024/10/16.
//

#import "MCSResources.h"

@implementation MCSResources
+ (NSBundle *)bundle {
    return [NSBundle bundleWithPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"SJMediaCacheServer" ofType:@"bundle"]];
}

+ (NSString *)filePathWithFilename:(NSString *)filename {
    return [[self bundle] pathForResource:filename ofType:nil];
}
@end
