//
//  MCSMimeType.h
//  SJMediaCacheServer
//
//  Created by db on 2024/10/16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *
MCSMimeTypeFromFileAtPath(NSString *path);

FOUNDATION_EXPORT NSString *
MCSMimeType(NSString *filenameExtension); // "mp3", "ts" ...

NS_ASSUME_NONNULL_END
