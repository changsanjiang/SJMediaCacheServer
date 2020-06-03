//
//  SJDataResponse.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJDataResponse.h"
#import "SJResource.h"

@interface SJDataResponse ()<SJResourceReaderDelegate>
@property (nonatomic, weak) id<SJDataResponseDelegate> delegate;
@property (nonatomic, strong) SJDataRequest * request;
@property (nonatomic, strong) SJResource *resource;
@property (nonatomic, strong) id<SJResourceReader> reader;
@end

@implementation SJDataResponse
- (instancetype)initWithRequest:(SJDataRequest *)request delegate:(id<SJDataResponseDelegate>)delegate {
    self = [super init];
    if ( self ) {
        _request = request;
    }
    return self;
}

- (void)prepare {
    _resource = [SJResource resourceWithURL:_request.URL];
    _reader = [_resource readDataWithRequest:_request];
    _reader.delegate = self;
    [_reader prepare];
}

- (UInt64)contentLength {
    return _reader.contentLength;
}

- (nullable NSData *)readDataOfLength:(NSUInteger)length {
    return [_reader readDataOfLength:length];
}

- (UInt64)offset {
    return _reader.offset;
}

- (BOOL)isDone {
    return _reader.isReadingEndOfData;
}

- (void)close {
    [_reader close];
}

#pragma mark -

- (void)readerPrepareDidFinish:(id<SJResourceReader>)reader {
    [_delegate responsePrepareDidFinish:self];
}

- (void)readerHasAvailableData:(id<SJResourceReader>)reader {
    [_delegate responseHasAvailableData:self];
}

- (void)reader:(id<SJResourceReader>)reader anErrorOccurred:(NSError *)error {
    [_delegate response:self anErrorOccurred:error];
}
@end
