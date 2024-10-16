//
//  MCSMimeType.m
//  SJMediaCacheServer
//
//  Created by db on 2024/10/16.
//

#import "MCSMimeType.h"
#import "MCSResources.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

FOUNDATION_EXPORT NSString *
MCSMimeTypeFromFileAtPath(NSString *path) {
    return MCSMimeType(path.pathExtension);
}

FOUNDATION_EXPORT NSString *
MCSMimeType(NSString *filenameExtension) {
    assert(filenameExtension != nil);
    NSString *mimeType = nil;
    if ( @available(iOS 14.0, *) ) {
        UTType *type = [UTType typeWithFilenameExtension:filenameExtension];
        mimeType = [type preferredMIMEType];
    }
    else {
        CFStringRef type = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)filenameExtension, NULL);
        if ( type != NULL) {
            CFStringRef ref = UTTypeCopyPreferredTagWithClass(type, kUTTagClassMIMEType);
            CFRelease(type);
            if ( ref != NULL ) mimeType = (__bridge_transfer NSString *)ref;
        }
    }
    
    if ( mimeType == nil ) {
        static NSDictionary<NSString *, NSString *> *commonMimeTypes;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSString *path = [MCSResources filePathWithFilename:@"common_mime_types.json"];
            NSData *data = [NSData dataWithContentsOfFile:path];
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:NULL];
            NSMutableDictionary<NSString *, NSString *> *m = NSMutableDictionary.dictionary;
            m[@"default_mime_type"] = json[@"default"] ?: @"application/octet-stream";
            [(NSArray<NSDictionary<NSString *, NSString *> *> *)json[@"list"] enumerateObjectsUsingBlock:^(NSDictionary<NSString *, NSString *> * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                m[obj[@"extension"]] = obj[@"mime_type"];
            }];
            commonMimeTypes = m.copy;
        });
        // 如果没有找到对应的MIME类型，返回默认类型
        mimeType = commonMimeTypes[filenameExtension] ?: commonMimeTypes[@"default_mime_type"];
    }
    return mimeType;
}
