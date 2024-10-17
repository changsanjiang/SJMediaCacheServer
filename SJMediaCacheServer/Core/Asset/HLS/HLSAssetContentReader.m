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
    }
    return self;
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

- (void)didAbortWithError:(NSError *)error {
    [mTask cancel];
}

#pragma mark - mark

/// unlocked
- (void)_downloadDidCompleteWithCurrentRequest:(NSURLRequest *)request data:(NSData *_Nullable)data error:(NSError *_Nullable)downloadError {
    if ( self.status == MCSReaderStatusAborted ) return;
    mTask = nil;
    
    NSError *error = nil;
    if ( downloadError != nil ) {
        error = [NSError mcs_errorWithCode:MCSDownloadError userInfo:@{
            MCSErrorUserInfoErrorKey : downloadError,
            MCSErrorUserInfoReasonKey : @"Playlist download failed!"
        }];
    }
    
    id<MCSAssetContent> content = nil;
    if ( error == nil ) {
        NSString *proxyPlaylist = [HLSAssetParser proxyPlaylistWithAsset:mAsset.name originalPlaylistData:data sourceURL:request.URL error:&error];
        if ( error == nil ) {
            content = [mAsset createPlaylistContent:proxyPlaylist error:&error]; // retain
        }
    }
    
    if ( error != nil ) {
        [self abortWithError:error];
        return;
    }
    [self contentDidReady:content range:NSMakeRange(0, content.length)];
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
    
    id<MCSAssetContent> content = [mAsset getAESKeyContentWithOriginalURL:mRequest.URL];
    if ( content != nil ) {
        [self contentDidReady:content range:NSMakeRange(0, content.length)];
    }
    else {
        mTask = [MCSContents request:[mRequest mcs_requestWithHTTPAdditionalHeaders:[mAsset.configuration HTTPAdditionalHeadersForDataRequestsOfType:MCSDataTypeHLSAESKey]] networkTaskPriority:mPriority completion:^(id<MCSDownloadTask>  _Nonnull task, NSData * _Nullable data, NSError * _Nullable downloadError) {
            @synchronized (self) {
                [self _downloadDidCompleteWithData:data error:downloadError];
            }
        }];
    }
}

- (void)didAbortWithError:(NSError *)error {
    [mTask cancel];
}

#pragma mark - mark

/// unlocked
- (void)_downloadDidCompleteWithData:(NSData *_Nullable)data error:(NSError *_Nullable)downloadError {
    if ( self.status == MCSReaderStatusAborted ) return;
    mTask = nil;
    
    NSError *error = nil;
    if ( downloadError != nil ) {
        error = [NSError mcs_errorWithCode:MCSDownloadError userInfo:@{
            MCSErrorUserInfoErrorKey : downloadError,
            MCSErrorUserInfoReasonKey : @"Playlist download failed!"
        }];
    }
    
    id<MCSAssetContent> content = nil;
    if ( error == nil ) {
        content = [mAsset createAESKeyContentWithOriginalURL:mRequest.URL data:data error:&error]; // retain
    }
    
    if ( error != nil ) {
        [self abortWithError:error];
        return;
    }
    [self contentDidReady:content range:NSMakeRange(0, content.length)];
}
@end

@implementation HLSAssetSegmentContentReader

@end
