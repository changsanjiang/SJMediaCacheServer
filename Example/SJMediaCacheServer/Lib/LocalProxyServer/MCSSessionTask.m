//
//  MCSSessionTask.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSSessionTask.h"
#import "MCSResource.h"

@interface MCSSessionTask ()<MCSResourceReaderDelegate>
@property (nonatomic, weak) id<MCSSessionTaskDelegate> delegate;
@property (nonatomic, strong) NSURLRequest * request;
@property (nonatomic, strong) MCSResource *resource;
@property (nonatomic, strong) id<MCSResourceReader> reader;
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
    if ( !_reader.isClosed ) [_delegate taskPrepareDidFinish:self];
}

- (void)readerHasAvailableData:(id<MCSResourceReader>)reader {
    if ( !_reader.isClosed ) [_delegate taskHasAvailableData:self];
}

- (void)reader:(id<MCSResourceReader>)reader anErrorOccurred:(NSError *)error {
    if ( !_reader.isClosed ) [_delegate task:self anErrorOccurred:error];
}
@end


//NSURLRequest:<0x6000019eee80> { URL: http://rec.app.lanwuzhe.com/recordings/z1.lanwuzhe.24086472/1589864400_1589950800.m3u8, headers: {
//    Accept = "*/*";
//    "Accept-Encoding" = identity;
//    "Accept-Language" = "en-us";
//    Connection = "keep-alive";
//    Host = "127.0.0.1:80";
//    Range = "bytes=0-1";
//    "User-Agent" = "AppleCoreMedia/1.0.0.17F61 (iPhone; U; CPU OS 13_5 like Mac OS X; en_us)";
//    "X-Playback-Session-Id" = "F6135639-3F0B-419F-ADD3-483EB82A8515";
//}
//};

//<NSHTTPURLResponse: 0x600003182c40> { URL: http://rec.app.lanwuzhe.com/recordings/z1.lanwuzhe.24086472/1589864400_1589950800.m3u8 } { Status Code: 200, Headers {
//    "Accept-Ranges" =     (
//        bytes
//    );
//    "Access-Control-Allow-Origin" =     (
//        "*"
//    );
//    "Access-Control-Expose-Headers" =     (
//        "X-Log, X-Reqid"
//    );
//    "Access-Control-Max-Age" =     (
//        2592000
//    );
//    Age =     (
//        1513106
//    );
//    "Ali-Swift-Global-Savetime" =     (
//        1590163823
//    );
//    Connection =     (
//        "keep-alive"
//    );
//    "Content-Disposition" =     (
//        "inline; filename=\"1589864400_1589950800.m3u8\"; filename*=utf-8''1589864400_1589950800.m3u8"
//    );
//    "Content-Length" =     (
//        59626
//    );
//    "Content-Md5" =     (
//        "qfmNnwW7Vd7n5HjxU7JmsA=="
//    );
//    "Content-Transfer-Encoding" =     (
//        binary
//    );
//    "Content-Type" =     (
//        "application/x-mpegurl"
//    );
//    Date =     (
//        "Fri, 22 May 2020 16:10:23 GMT"
//    );
//    EagleId =     (
//        b4a3792015916769294671086e
//    );
//    Etag =     (
//        "\"FlpnyGPeEs-AHEFlvLZYzjBETi8F\""
//    );
//    "Last-Modified" =     (
//        "Tue, 19 May 2020 06:56:20 GMT"
//    );
//    Server =     (
//        Tengine
//    );
//    "Timing-Allow-Origin" =     (
//        "*"
//    );
//    Via =     (
//        "cache35.l2cn1824[0,200-0,H], cache3.l2cn1824[10,0], vcache19.cn1996[0,200-0,H], vcache12.cn1996[16,0]"
//    );
//    "X-Cache" =     (
//        "HIT TCP_HIT dirn:11:552567801"
//    );
//    "X-Log" =     (
//        "X-Log"
//    );
//    "X-M-Log" =     (
//        "QNM:zz609;QNM3"
//    );
//    "X-M-Reqid" =     (
//        CzAAAKp68oiSZREW
//    );
//    "X-Qiniu-Zone" =     (
//        1
//    );
//    "X-Qnm-Cache" =     (
//        Hit
//    );
//    "X-Reqid" =     (
//        vlAAAAA5F0ApZRAW
//    );
//    "X-Svr" =     (
//        IO
//    );
//    "X-Swift-CacheTime" =     (
//        2592000
//    );
//    "X-Swift-SaveTime" =     (
//        "Tue, 09 Jun 2020 04:05:53 GMT"
//    );
//} }
