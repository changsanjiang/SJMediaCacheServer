//
//  MCSHLSReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSReader.h"
#import "MCSHLSResource.h"

@interface MCSHLSReader ()<NSLocking> {
    NSRecursiveLock *_lock;
@protected
    BOOL _isCalledPrepare;
    BOOL _isClosed;
    BOOL _isPrepared;
}
- (instancetype)_initWithResource:(__weak MCSHLSResource *)resource request:(NSURLRequest *)request;
@property (nonatomic, weak, nullable) MCSHLSResource *resource;
@property (nonatomic, strong, nullable) NSURLRequest *request;
@end

@interface MCSHLSM3u8Reader : MCSHLSReader<MCSResourceReader>

@end

@implementation MCSHLSM3u8Reader
- (void)prepare {
    [self lock];
    @try {
        if ( _isClosed || _isCalledPrepare )
            return;
        
        // 解析mu38文件, 为后续的播放做准备
        // 1. 需在本地生成一组播放列表文件
        // 2. aes加密文件的处理
        // 3. ts文件的处理
        
        // 下载原始文件内容
        
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}
@end


@implementation MCSHLSReader
- (instancetype)initWithResource:(__weak MCSHLSResource *)resource request:(NSURLRequest *)request {
    if ( [request.URL.lastPathComponent hasSuffix:@"m3u8"] )
        return [MCSHLSM3u8Reader.alloc initWithResource:resource request:request];
    
    return [self _initWithResource:resource request:request];
}

- (instancetype)_initWithResource:(__weak MCSHLSResource *)resource request:(NSURLRequest *)request {
    self = [super init];
    if ( self ) {
        _resource = resource;
        _request = request;
        _lock = NSRecursiveLock.alloc.init;
    }
    return self;
}

- (void)prepare {
    [self lock];
    @try {
        
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    return nil;
}

- (void)close {
    
}


- (void)lock {
    [_lock lock];
}

- (void)unlock {
    [_lock unlock];
}
@end
