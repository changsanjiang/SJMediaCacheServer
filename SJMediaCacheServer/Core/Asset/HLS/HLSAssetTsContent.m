//
//  HLSAssetTsContent.m
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/11/25.
//

#import "HLSAssetTsContent.h"
#import "MCSMimeType.h"
 
@implementation HLSAssetTsContent
- (instancetype)initWithSourceURL:(NSURL *)URL name:(NSString *)name filepath:(NSString *)filepath totalLength:(UInt64)totalLength length:(UInt64)length {
    return [self initWithSourceURL:URL name:name filepath:filepath totalLength:totalLength length:length rangeInAsset:NSMakeRange(0, totalLength)];
}
- (instancetype)initWithSourceURL:(NSURL *)URL name:(NSString *)name filepath:(NSString *)filepath totalLength:(UInt64)totalLength {
    return [self initWithSourceURL:URL name:name filepath:filepath totalLength:totalLength length:0];
}
- (instancetype)initWithSourceURL:(NSURL *)URL name:(NSString *)name filepath:(NSString *)filepath totalLength:(UInt64)totalLength rangeInAsset:(NSRange)range {
    return [self initWithSourceURL:URL name:name filepath:filepath totalLength:totalLength length:0 rangeInAsset:range];
}
- (instancetype)initWithSourceURL:(NSURL *)URL name:(NSString *)name filepath:(NSString *)filepath totalLength:(UInt64)totalLength length:(UInt64)length rangeInAsset:(NSRange)range {
    self = [super initWithMimeType:MCSMimeType(URL.path.pathExtension) filepath:filepath startPositionInAsset:range.location length:length];
    if ( self ) {
        _name = name;
        _rangeInAsset = range;
        _totalLength = totalLength;
    }
    return self;
}
@end
