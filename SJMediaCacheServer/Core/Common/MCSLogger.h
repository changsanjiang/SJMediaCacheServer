//
//  MCSLogger.h
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/8.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCSDefines.h"

NS_ASSUME_NONNULL_BEGIN
@interface MCSLogger : NSObject
+ (instancetype)shared;

/// If yes, the log will be output on the console. The default value is NO.
@property (nonatomic, getter=isEnabledConsoleLog) BOOL enabledConsoleLog;

/// The default value is MCSLogOptionDefault.
@property (nonatomic) MCSLogOptions options;

- (void)option:(MCSLogOptions)option addLog:(NSString *)format, ... NS_FORMAT_FUNCTION(2,3);

@end

#ifdef DEBUG
#define MCSLog(__option__, format, arg...) \
[MCSLogger.shared option:__option__ addLog:format, ##arg]

// prefetcher
#define MCSPrefetcherLog(format, arg...) \
MCSLog(MCSLogOptionPrefetcher, format, ##arg)

// resource reader
#define MCSResourceReaderLog(format, arg...) \
MCSLog(MCSLogOptionResourceReader, format, ##arg)

// data reader
#define MCSDataReaderLog(format, arg...) \
MCSLog(MCSLogOptionDataReader, format, ##arg)

// download
#define MCSDownloadLog(format, arg...) \
MCSLog(MCSLogOptionDownload, format, ##arg)

// HTTP connection
#define MCSHTTPConnectionLog(format, arg...) \
MCSLog(MCSLogOptionHTTPConnection, format, ##arg)

#else
#define MCSLog(option, format, arg...)
#define MCSPrefetcherLog(format, arg...)
#define MCSResourceReaderLog(format, arg...)
#define MCSDataReaderLog(format, arg...)
#define MCSDownloadLog(format, arg...)
#define MCSHTTPConnectionLog(format, arg...)
#endif
NS_ASSUME_NONNULL_END
