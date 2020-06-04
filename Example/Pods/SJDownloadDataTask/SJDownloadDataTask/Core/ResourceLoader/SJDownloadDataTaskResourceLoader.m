//
//  LWZACFResourceLoader.m
//  Pods
//
//  Created by BlueDancer on 2019/5/31.
//

#import "SJDownloadDataTaskResourceLoader.h"

@implementation SJDownloadDataTaskResourceLoader
+ (NSBundle *)bundle {
    return [NSBundle bundleWithPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"SJDownloadDataTask" ofType:@"bundle"]];
}
@end
