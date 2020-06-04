//
//  SJOutPutStream.m
//  SJDownloadDataTask
//
//  Created by BlueDancer on 2019/1/14.
//  Copyright © 2019 畅三江. All rights reserved.
//

#import "SJOutPutStream.h"

@implementation SJOutPutStream {
    NSOutputStream *_outputStream;
}

- (instancetype)initWithPath:(NSURL *)filePath append:(BOOL)shouldAppend {
    self = [super init];
    if ( !self ) return nil;
    _outputStream = [[NSOutputStream alloc] initWithURL:filePath append:shouldAppend];
    return self;
}

- (void)open {
    [_outputStream open];
}

- (void)close {
    [_outputStream close];
}

- (NSInteger)write:(NSData *)data {
    return [_outputStream write:data.bytes maxLength:data.length];
}

- (void)dealloc {
    [_outputStream close];
#ifdef SJ_MAC
    NSLog(@"%d - %s", (int)__LINE__, __func__);
#endif
}
@end
