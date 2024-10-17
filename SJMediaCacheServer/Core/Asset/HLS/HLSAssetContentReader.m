//
//  HLSAssetContentReader.m
//  SJMediaCacheServer
//
//  Created by 畅三江 on 2021/7/19.
//

#import "HLSAssetContentReader.h"
#import "HLSAsset.h"
#import "MCSLogger.h"
#import "MCSContents.h"
#import "MCSError.h"
#import "MCSAssetContent.h"
#import "NSFileManager+MCS.h"
#import "HLSAssetParser.h"

@interface HLSAssetPlaylistContentReader () {
    HLSAsset *mAsset;
    NSURLRequest *mRequest;
    float mPriority;
    id<MCSDownloadTask> _Nullable mTask; // download playlist
}
@end

@implementation HLSAssetPlaylistContentReader

- (instancetype)initWithAsset:(HLSAsset *)asset request:(NSURLRequest *)request networkTaskPriority:(float)priority delegate:(id<MCSAssetContentReaderDelegate>)delegate {
    self = [super initWithAsset:asset delegate:delegate];
    if ( self ) {
        mAsset = asset;
        mRequest = request;
        mPriority = priority;
        [mAsset readwriteRetain];
    }
    return self;
}

- (void)dealloc {
    [mAsset readwriteRelease];
}

- (void)prepareContent {
    id<MCSAssetContent> content = [mAsset getPlaylistContent];
    if ( content != nil ) {
        [self contentDidReady:content range:NSMakeRange(0, content.length)];
    }
    else {
        mTask = [MCSContents request:mRequest networkTaskPriority:mPriority completion:^(id<MCSDownloadTask>  _Nonnull task, NSData * _Nullable data, NSError * _Nullable error) {
            @synchronized (self) {
                [self _downloadDidCompleteWithCurrentRequest:task.currentRequest data:data error:error];
            }
        }];
    }
}

#pragma mark - mark

/// unlocked
- (void)_downloadDidCompleteWithCurrentRequest:(NSURLRequest *)request data:(NSData *_Nullable)data error:(NSError *_Nullable)downloadError {
    if ( self.status == MCSReaderStatusAborted ) return;
    mTask = nil;
    if ( downloadError != nil ) {
        [self abortWithError:[NSError mcs_errorWithCode:MCSDownloadError userInfo:@{
            MCSErrorUserInfoErrorKey : downloadError,
            MCSErrorUserInfoReasonKey : @"Playlist download failed!"
        }]];
        return;
    }
    
    NSError *error = nil;
    id<MCSAssetContent> content = nil;
    NSString *proxyPlaylist = [HLSAssetParser proxyPlaylistWithAsset:mAsset.name originalPlaylistData:data sourceURL:request.URL error:&error];
    if ( error == nil ) {
        content = [mAsset createPlaylistContent:proxyPlaylist error:&error]; // retain
    }
    if ( error != nil ) {
        [self abortWithError:error];
        return;
    }
    [self contentDidReady:content range:NSMakeRange(0, content.length)];
}

#pragma mark - mark

- (void)didAbortWithError:(NSError *)error {
    [mTask cancel];
}
@end


#pragma mark -

@implementation HLSAssetAESKeyContentReader {
    HLSAsset *mAsset;
    NSURLRequest *mRequest;
    float mPriority;
    id<MCSDownloadTask> _Nullable mTask;
}

- (instancetype)initWithAsset:(HLSAsset *)asset request:(NSURLRequest *)request networkTaskPriority:(float)priority delegate:(id<MCSAssetContentReaderDelegate>)delegate {
    self = [super initWithAsset:asset delegate:delegate];
    if ( self ) {
        mAsset = asset;
        mRequest = request;
        mPriority = priority;
    }
    return self;
}

- (void)prepareContent {
    
    MCSContentReaderDebugLog(@"%@: <%p>.prepare { request: %@\n };\n", NSStringFromClass(self.class), self, mRequest.mcs_description);

    NSString *filepath = [mAsset AESKeyFilepathWithURL:mRequest.URL];
    @synchronized (HLSAssetAESKeyContentReader.class) {
        if ( [NSFileManager.defaultManager fileExistsAtPath:filepath] ) {
            [self _createContentAtPath:filepath];
            return;
        }
    }
    
    MCSContentReaderDebugLog(@"%@: <%p>.download { request: %@\n };\n", NSStringFromClass(self.class), self, mRequest.mcs_description);
    [self _downloadToFile:filepath];
}

- (void)didAbortWithError:(NSError *)error {
    [mTask cancel];
}

- (void)_downloadToFile:(NSString *)filepath {
    mTask = [MCSContents request:[mRequest mcs_requestWithHTTPAdditionalHeaders:[mAsset.configuration HTTPAdditionalHeadersForDataRequestsOfType:MCSDataTypeHLSAESKey]] networkTaskPriority:mPriority completion:^(id<MCSDownloadTask>  _Nonnull task, NSData * _Nullable data, NSError * _Nullable downloadError) {
        @synchronized (self) {
            [self _downloadDidCompleteWithData:data error:downloadError saveToFile:filepath];
        }
    }];
}

/// unlocked
- (void)_downloadDidCompleteWithData:(NSData *_Nullable)data error:(NSError *_Nullable)downloadError saveToFile:(NSString *)filepath {
    if ( self.status == MCSReaderStatusAborted ) return;

    NSError *writeError = nil;
    if ( downloadError == nil ) {
        @synchronized (HLSAssetAESKeyContentReader.class) {
            if ( ![NSFileManager.defaultManager fileExistsAtPath:filepath] ) {
                [data writeToFile:filepath options:NSDataWritingAtomic error:&writeError]; // write data to file
            }
        }
    }
    
    NSError *error = downloadError ?: writeError;
    if ( error != nil ) {
        [self abortWithError:[NSError mcs_errorWithCode:MCSFileError userInfo:@{
            MCSErrorUserInfoErrorKey : error,
            MCSErrorUserInfoReasonKey : @"下载失败或写入文件失败!"
        }]];
        return;
    }
    
    [self _createContentAtPath:filepath];
}

- (void)_createContentAtPath:(NSString *)filepath {
    UInt64 fileSize = (UInt64)[NSFileManager.defaultManager mcs_fileSizeAtPath:filepath];
    MCSAssetContent *content = [MCSAssetContent.alloc initWithFilepath:filepath startPositionInAsset:0 length:fileSize];
    [content readwriteRetain];
    [self contentDidReady:content range:NSMakeRange(0, content.length)];
}
@end

@implementation HLSAssetMediaSegmentContentReader

@end
