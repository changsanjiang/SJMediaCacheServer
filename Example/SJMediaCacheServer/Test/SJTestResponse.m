//
//  SJTestResponse.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJTestResponse.h"

@interface SJTestResponse ()
@property (nonatomic, strong) id<SJDataRequest> request;
@property (nonatomic, weak, nullable) id<SJDataResponseDelegate> delegate;
@property (nonatomic, strong, nullable) NSFileHandle *fileHandler;
@end

@implementation SJTestResponse
@synthesize contentLength = _contentLength;

- (instancetype)initWithRequest:(id<SJDataRequest>)request delegate:(id<SJDataResponseDelegate>)delegate {
    self = [super init];
    if ( self ) {
        _request = request;
        _delegate = delegate;
    }
    return self;
}

- (void)prepare {
    NSString *path = [NSBundle.mainBundle pathForResource:@"audio" ofType:@"m4a"];
    _contentLength = [[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil][NSFileSize] unsignedLongValue];
    _fileHandler = [NSFileHandle fileHandleForReadingAtPath:path];
    [_fileHandler seekToFileOffset:_request.range.location];
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    return [_fileHandler readDataOfLength:length];
}

- (UInt64)offset {
    return _fileHandler.offsetInFile;
}
 
- (BOOL)isDone {
    return _fileHandler.offsetInFile == NSMaxRange(_request.range);
}

- (void)close {
    
}
@end
