//
//  MCSDataResponse.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSDataResponse.h"
#import "MCSResource.h"

@interface MCSDataResponse ()<MCSResourceReaderDelegate>
@property (nonatomic, weak) id<MCSDataResponseDelegate> delegate;
@property (nonatomic, strong) MCSDataRequest * request;
@property (nonatomic, strong) MCSResource *resource;
@property (nonatomic, strong) id<MCSResourceReader> reader;
@end

@implementation MCSDataResponse
- (instancetype)initWithRequest:(MCSDataRequest *)request delegate:(id<MCSDataResponseDelegate>)delegate {
    self = [super init];
    if ( self ) {
        _request = request;
        _delegate = delegate;
    }
    return self;
}

- (void)prepare {
    _resource = [MCSResource resourceWithURL:_request.URL];
    _reader = [_resource readerWithRequest:_request];
    _reader.delegate = self;
    [_reader prepare];
}

- (NSDictionary *)responseHeaders {
    return _reader.response.responseHeaders;
}

- (NSUInteger)contentLength {
    return _reader.response.totalLength;
}

- (nullable NSData *)readDataOfLength:(NSUInteger)length {
    return [_reader readDataOfLength:length];
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
    [_reader close];
}

#pragma mark -

- (void)readerPrepareDidFinish:(id<MCSResourceReader>)reader {
    if ( !_reader.isClosed ) [_delegate responsePrepareDidFinish:self];
}

- (void)readerHasAvailableData:(id<MCSResourceReader>)reader {
    if ( !_reader.isClosed ) [_delegate responseHasAvailableData:self];
}

- (void)reader:(id<MCSResourceReader>)reader anErrorOccurred:(NSError *)error {
    if ( !_reader.isClosed ) [_delegate response:self anErrorOccurred:error];
}
@end
