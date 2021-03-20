//
//  MCSRootDirectory.m
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/11/26.
//

#import "MCSRootDirectory.h" 
#import "NSFileManager+MCS.h"

@implementation MCSRootDirectory
static NSString *mcs_path;
+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mcs_path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:@"com.SJMediaCacheServer.cache"];
        [NSFileManager.defaultManager mcs_createDirectoryAtPath:mcs_path backupable:NO];
    });
}

+ (NSString *)path {
    return mcs_path;
}

+ (unsigned long long)size {
#warning next .. 需要减去数据库的大小
    return [NSFileManager.defaultManager mcs_directorySizeAtPath:mcs_path];
}

+ (NSString *)assetPathForFilename:(NSString *)filename {
    return [mcs_path stringByAppendingPathComponent:filename];
}

+ (NSString *)databasePath {
    return [mcs_path stringByAppendingPathComponent:@"mcs.db"];
}
@end
