//
//  MCSHLSAESKeyDataReader.m
//  SJMediaCacheServer
//
//  Created by 畅三江 on 2020/6/23.
//

#import "MCSHLSAESKeyDataReader.h"
#import "MCSHLSResource.h"
#import "MCSFileManager.h"
#import "MCSError.h"
#import "MCSResourceResponse.h"

@interface MCSHLSAESKeyDataReader ()
@property (nonatomic, strong) NSURL *URL;
@end

@implementation MCSHLSAESKeyDataReader
- (instancetype)initWithResource:(MCSHLSResource *)resource URL:(nonnull NSURL *)URL {
    NSString *path = [resource AESKeyFilePath];
    NSRange range = NSMakeRange(0, [MCSFileManager fileSizeAtPath:path]);
    NSRange readRange = range;
    self = [super initWithRange:range path:path readRange:readRange];
    if ( self ) {
        _URL = URL;
    }
    return self;
}

- (void)prepare {
    if ( ![MCSFileManager fileExistsAtPath:self.path] ) {
        [self.delegate reader:self anErrorOccurred:[NSError mcs_errorForFileHandleError:_URL]];
        return;
    }
    
    _response = [MCSResourceResponse.alloc initWithServer:@"localhost" contentType:@"application/octet-stream" totalLength:[MCSFileManager fileSizeAtPath:self.path]];
    
    [super prepare];
}

@end
