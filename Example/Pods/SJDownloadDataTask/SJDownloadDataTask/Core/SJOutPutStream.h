//
//  SJOutPutStream.h
//  SJDownloadDataTask
//
//  Created by BlueDancer on 2019/1/14.
//  Copyright © 2019 畅三江. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SJOutPutStream : NSObject
- (instancetype)initWithPath:(NSURL *)filePath append:(BOOL)shouldAppend;
- (void)open;
- (void)close;
- (NSInteger)write:(NSData *)data;
@end

NS_ASSUME_NONNULL_END
