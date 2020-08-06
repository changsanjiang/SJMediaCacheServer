//
//  MCSResource.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSResource.h"
#import "MCSFileManager.h"
#import "MCSResourceSubclass.h"
#import "MCSResourceManager.h"
#import "MCSConfiguration.h"
#import "MCSQueue.h"

@interface MCSResource ()
@property (nonatomic) NSInteger id;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) MCSResourceUsageLog *log;
@property (nonatomic) NSInteger readWriteCount;
@property (nonatomic) BOOL isCacheFinished;
@end

@implementation MCSResource

- (instancetype)init {
    self = [super init];
    if ( self ) {
        _configuration = MCSConfiguration.alloc.init;
        _m = NSMutableArray.array;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name {
    self = [self init];
    if ( self ) {
        _name = name;
    }
    return self;
} 

- (MCSResourceType)type {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];
}

- (id<MCSResourceReader>)readerWithRequest:(NSURLRequest *)request {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];
}
 
- (void)prepareForReader {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];
}

- (nullable MCSResourcePartialContent *)createContentForDataReaderWithProxyURL:(NSURL *)proxyURL response:(NSHTTPURLResponse *)response {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];
}

- (NSString *)filePathOfContent:(MCSResourcePartialContent *)content {
    return [MCSFileManager getFilePathWithName:content.filename inResource:_name];
}

- (void)didWriteDataForContent:(MCSResourcePartialContent *)content length:(NSUInteger)length {
    dispatch_barrier_sync(MCSResourceQueue(), ^{
        [self _didWriteDataForContent:content length:length];
    });
}

- (void)willReadContent:(MCSResourcePartialContent *)content {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];
}

- (void)didEndReadContent:(MCSResourcePartialContent *)content {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];
}

#pragma mark -

- (BOOL)isCacheFinished {
    __block BOOL isCacheFinished = NO;
    dispatch_sync(MCSResourceQueue(), ^{
        isCacheFinished = _isCacheFinished;
    });
    return isCacheFinished;
}

- (nullable NSURL *)playbackURLForCacheWithURL:(NSURL *)URL {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
      reason:[NSString stringWithFormat:@"You must override %@ in a subclass.", NSStringFromSelector(_cmd)]
    userInfo:nil];
}

@synthesize readWriteCount = _readWriteCount;
- (void)setReadWriteCount:(NSInteger)readWriteCount {
    dispatch_barrier_sync(MCSResourceQueue(), ^{
        _readWriteCount = readWriteCount;
    });
}

- (NSInteger)readWriteCount {
    __block NSInteger readWriteCount;
    dispatch_sync(MCSResourceQueue(), ^{
        readWriteCount = _readWriteCount;
    });
    return readWriteCount;
}

- (void)readWrite_retain {
    self.readWriteCount += 1;
}

- (void)readWrite_release {
    self.readWriteCount -= 1;
}

#pragma mark -

- (NSArray<MCSResourcePartialContent *> *)contents {
    __block NSArray<MCSResourcePartialContent *> *contents = nil;
    dispatch_sync(MCSResourceQueue(), ^{
        contents = _m.count > 0 ? _m.copy : nil;
    });
    return contents;
}

- (void)_addContents:(NSArray<MCSResourcePartialContent *> *)contents {
    if ( contents.count != 0 ) {
        [_m addObjectsFromArray:contents];
        [self _contentsDidChange:_m.copy];
    }
}

- (void)_addContent:(MCSResourcePartialContent *)content {
    if ( content != nil ) [self _addContents:@[content]];
}

- (void)_removeContent:(MCSResourcePartialContent *)content {
    if ( content != nil ) {
        [self _removeContents:@[content]];
    }
}

- (void)_removeContents:(NSArray<MCSResourcePartialContent *> *)contents {
    NSUInteger length = 0;
    for ( MCSResourcePartialContent *content in contents ) {
        length += content.length;
        [MCSFileManager removeContentWithName:content.filename inResource:_name error:NULL];
    }
    [_m removeObjectsInArray:contents];
    [self _contentsDidChange:_m.copy];
    [MCSResourceManager.shared didRemoveDataForResource:self length:length];
}

- (void)_contentsDidChange:(NSArray<MCSResourcePartialContent *> *)contents {
    /* subclass */
}

- (void)_didWriteDataForContent:(MCSResourcePartialContent *)content length:(NSUInteger)length {
    [content didWriteDataWithLength:length];
    [MCSResourceManager.shared didWriteDataForResource:self length:length];
}
@end
