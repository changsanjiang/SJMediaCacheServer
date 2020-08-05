//
//  MCSSessionTask.m
//  SJMediaCacheServer_Example
//
//  Created by 畅三江 on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSSessionTask.h"
#import "MCSResourceManager.h"
#import "MCSUtils.h"
#import "MCSLogger.h"

@interface MCSSessionTask ()<MCSResourceReaderDelegate>
@property (nonatomic, weak) id<MCSSessionTaskDelegate> delegate;
@property (nonatomic, strong) NSURLRequest * request;
@property (nonatomic, strong) id<MCSResource> resource;
@property (nonatomic, strong) id<MCSResourceReader> reader;
#ifdef DEBUG
@property (nonatomic) uint64_t startTime;
#endif
@end

@implementation MCSSessionTask
- (instancetype)initWithRequest:(NSURLRequest *)request delegate:(id<MCSSessionTaskDelegate>)delegate {
    self = [super init];
    if ( self ) {
        _request = request;
        _delegate = delegate;
    }
    return self;
}

- (void)prepare {
#ifdef DEBUG
    MCSSessionTaskLog(@"%@: <%p>.prepare { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);
    _startTime = MCSTimerStart();
#endif
    
    _reader = [MCSResourceManager.shared readerWithRequest:_request];
    _reader.delegate = self;
    @autoreleasepool {
        [_reader prepare];
    }
}

- (NSDictionary *)responseHeaders {
    return _reader.response.responseHeaders;
}

- (NSUInteger)contentLength {
    return _reader.response.totalLength;
}

- (nullable NSData *)readDataOfLength:(NSUInteger)length {
    NSData *data = [_reader readDataOfLength:length];
#ifdef DEBUG
    if ( data.length != 0 ) {
        MCSSessionTaskLog(@"%@: <%p>.read { length: %lu };\n", NSStringFromClass(self.class), self, (unsigned long)data.length);
        if ( _reader.isReadingEndOfData )
            MCSSessionTaskLog(@"%@: <%p>.done { after (%lf) seconds, URL: %@ };\n", NSStringFromClass(self.class), self, MCSTimerMilePost(_startTime), _request.URL);
    }
#endif
    return data;
}

- (NSUInteger)offset {
    return _reader.offset;
}

- (BOOL)isPrepared {
    return _reader.isPrepared;
}

- (BOOL)isDone {
    return _reader.isReadingEndOfData;
}

- (void)close {
    MCSSessionTaskLog(@"%@: <%p>.close;\n\n", NSStringFromClass(self.class), self);
    [_reader close];
}

#pragma mark -

- (void)readerPrepareDidFinish:(id<MCSResourceReader>)reader {
    if ( !reader.isClosed ) [_delegate taskPrepareDidFinish:self];
}

- (void)reader:(id<MCSResourceReader>)reader hasAvailableDataWithLength:(NSUInteger)length {
    if ( !reader.isClosed ) [_delegate taskHasAvailableData:self];
}

- (void)reader:(id<MCSResourceReader>)reader anErrorOccurred:(NSError *)error {
    [reader close];
    [_delegate task:self anErrorOccurred:error];
}
@end
