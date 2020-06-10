//
//  MCSHLSTSDataReader.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/10.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSHLSTSDataReader.h"
#import "MCSResourceFileManager.h"
#import "MCSLogger.h"
#import "MCSHLSResource.h"
#import "MCSResourceSubclass.h"
#import "MCSResourceNetworkDataReader.h"
#import "MCSResourceFileDataReader.h"

@interface MCSHLSTSDataReader ()
@property (nonatomic, weak, nullable) MCSHLSResource *resource;
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) MCSHLSParser *parser;

@property (nonatomic) BOOL isCalledPrepare;
@property (nonatomic) BOOL isClosed;
@property (nonatomic) BOOL isDone;
@end

@implementation MCSHLSTSDataReader
@synthesize delegate = _delegate;

- (instancetype)initWithResource:(MCSHLSResource *)resource Request:(NSURLRequest *)request parser:(MCSHLSParser *)parser {
    self = [super init];
    if ( self ) {
        _resource = resource;
        _request = request;
        _parser = parser;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@:<%p> { URL: %@\n };", NSStringFromClass(self.class), self, _request.URL];
}

- (void)prepare {
    if ( _isClosed || _isCalledPrepare )
        return;
    
    MCSLog(@"%@: <%p>.prepare { URL: %@ };\n", NSStringFromClass(self.class), self, _request.URL);

    _isCalledPrepare = YES;

    NSString *filename = [MCSResourceFileManager hls_tsFilenameForUrl:_request.URL.absoluteString];
    NSString *filepath = [MCSResourceFileManager getFilePathWithName:filename inResource:_resource.name];
    if ( [NSFileManager.defaultManager fileExistsAtPath:filepath] ) {

#warning next .... 下一步 ts 的存储问题
        
    }
}

- (NSData *)readDataOfLength:(NSUInteger)length {
    return nil;
}

//@property (nonatomic, readonly) BOOL isDone;
//@property (nonatomic, strong, readonly, nullable) id<MCSResourceResponse> response;
//- (nullable NSData *)readDataOfLength:(NSUInteger)length;
- (void)close {
    
}
@end
