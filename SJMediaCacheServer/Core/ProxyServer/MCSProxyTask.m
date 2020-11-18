//
//  MCSProxyTask.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSProxyTask.h"
#import "MCSAssetManager.h"

@interface MCSProxyTask ()<MCSAssetReaderDelegate>
@property (nonatomic, weak) id<MCSProxyTaskDelegate> delegate;
@property (nonatomic, strong) NSURLRequest * request;
@property (nonatomic, strong) id<MCSAsset> asset;
@property (nonatomic, strong) id<MCSAssetReader> reader;
@end

@implementation MCSProxyTask
- (instancetype)initWithRequest:(NSURLRequest *)request delegate:(id<MCSProxyTaskDelegate>)delegate {
    self = [super init];
    if ( self ) {
        _request = request;
        _delegate = delegate;
    }
    return self;
}

- (void)prepare {
    _reader = [MCSAssetManager.shared readerWithRequest:_request];
    _reader.delegate = self;
    @autoreleasepool {
        [_reader prepare];
    }
}
 
- (nullable NSData *)readDataOfLength:(NSUInteger)length {
    return [_reader readDataOfLength:length];
}

- (NSUInteger)offset {
    return _reader.offset;
}

- (id<MCSResponse>)response {
    return _reader.response;
}

- (BOOL)isPrepared {
    return _reader.isPrepared;
}

- (BOOL)isDone {
    return _reader.isReadingEndOfData;
}

- (void)close {
    [_reader close];
}

#pragma mark -

- (void)reader:(id<MCSAssetReader>)reader prepareDidFinish:(id<MCSResponse>)response {
    if ( !reader.isClosed ) [_delegate taskPrepareDidFinish:self];
}

- (void)reader:(id<MCSAssetReader>)reader hasAvailableDataWithLength:(NSUInteger)length {
    if ( !reader.isClosed ) [_delegate taskHasAvailableData:self];
}

- (void)reader:(id<MCSAssetReader>)reader anErrorOccurred:(NSError *)error {
    [reader close];
    [_delegate task:self anErrorOccurred:error];
}
@end
