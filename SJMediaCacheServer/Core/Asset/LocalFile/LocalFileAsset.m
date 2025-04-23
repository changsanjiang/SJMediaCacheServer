//
//  LocalFileAsset.m
//  SJMediaCacheServer
//
//  Created by db on 2025/4/17.
//

#import "LocalFileAsset.h"
#import "MCSRootDirectory.h"
#import "LocalFileAssetReader.h"
#import "MCSConfiguration.h"
#import "MCSRequest.h"
#import "MCSAssetContent.h"
#import "NSFileManager+MCS.h"

@interface LocalFileAsset () {
    NSHashTable<id<MCSAssetObserver>> *mObservers;
    MCSConfiguration *mConfiguration;
    MCSAssetContent *mContent;
}

@property (nonatomic) NSInteger id; // saveable
@property (nonatomic, copy) NSString *name; // saveable
@property (nonatomic, copy, nullable) NSString *pathExtension; // saveable
@property (nonatomic) NSUInteger totalLength;  // saveable
@end

@implementation LocalFileAsset
@synthesize id = _id;
@synthesize name = _name;

+ (NSString *)sql_primaryKey {
    return @"id";
}

+ (NSArray<NSString *> *)sql_autoincrementlist {
    return @[@"id"];
}

+ (NSArray<NSString *> *)sql_blacklist {
    return @[@"readwriteCount", @"isStored", @"configuration", @"contents", @"provider"];
}

- (instancetype)initWithName:(NSString *)name {
    self = [super init];
    _name = name.copy;
    return self;
}

- (void)dealloc {
    [mObservers removeAllObjects];
}

- (BOOL)isStored {
    return true;
}

- (float)completeness {
    return 1;
}

- (id<MCSConfiguration>)configuration {
    return mConfiguration;
}

- (NSString *)path {
    return [MCSRootDirectory assetPathForFilename:_name];
}

- (void)prepare {
    mConfiguration = MCSConfiguration.alloc.init;
}

- (nullable id<MCSAssetContent>)createContentWithDataType:(MCSDataType)dataType response:(id<MCSDownloadResponse>)response error:(NSError **)error {
    return nil;
}

- (nullable id<MCSAssetReader>)readerWithRequest:(id<MCSRequest>)request networkTaskPriority:(float)networkTaskPriority readDataDecryptor:(NSData *(^_Nullable)(NSURLRequest *request, NSUInteger offset, NSData *data))readDataDecryptor delegate:(nullable id<MCSAssetReaderDelegate>)delegate {
    return [LocalFileAssetReader.alloc initWithAsset:self request:request networkTaskPriority:networkTaskPriority readDataDecryptor:readDataDecryptor delegate:delegate];
}

- (void)clear {
    
}

- (void)registerObserver:(id<MCSAssetObserver>)observer {
    if ( observer != nil ) {
        @synchronized (self) {
            if ( mObservers == nil ) {
                mObservers = NSHashTable.weakObjectsHashTable;
            }
            [mObservers addObject:observer];
        }
    }
}

- (void)removeObserver:(id<MCSAssetObserver>)observer {
    @synchronized (self) {
        [mObservers removeObject:observer];
    }
}

- (id<MCSAssetContent>)getContentWithRequest:(id<MCSRequest>)request {
    @synchronized (self) {
        if ( !mContent ) {
            MCSRequest *req = (id)request;
            NSURL *fileURL = req.originalURL;
            NSString *filePath = fileURL.path;
            mContent = [MCSAssetContent.alloc initWithFilePath:filePath position:0 length:[NSFileManager.defaultManager mcs_fileSizeAtPath:filePath]];
        }
        return mContent;
    }
}
@end
