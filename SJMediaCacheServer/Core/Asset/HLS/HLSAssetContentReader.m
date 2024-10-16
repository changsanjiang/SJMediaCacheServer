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
    mTask = [MCSContents request:[mRequest mcs_requestWithHTTPAdditionalHeaders:[mAsset.configuration HTTPAdditionalHeadersForDataRequestsOfType:MCSDataTypeHLSAESKey]] networkTaskPriority:mPriority willPerformHTTPRedirection:nil completion:^(NSData * _Nullable data, NSError * _Nullable downloadError) {
        @synchronized (self) {
            [self _downloadDidCompleteWithData:data error:downloadError saveToFile:filepath];
        }
    }];
}

/// unlocked
- (void)_downloadDidCompleteWithData:(NSData *_Nullable)data error:(NSError *_Nullable)downloadError saveToFile:(NSString *)filepath {
    if ( self.status == MCSReaderStatusAborted )
        return;
    
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


#pragma mark - mark

#import "HLSAssetParser.h"

@interface HLSAssetIndexContentReader ()<HLSAssetParserDelegate> {
    HLSAsset *mAsset;
    NSURLRequest *mRequest;
    float mPriority;
    HLSAssetParser *mTempParser;
}
@end

@implementation HLSAssetIndexContentReader

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
    HLSAssetParser *_Nullable parser = mAsset.parser;
    if ( parser != nil ) {
        [self _createContentWithParser:parser];
    }
    else {
        mTempParser = [HLSAssetParser.alloc initWithAsset:mAsset request:[mRequest mcs_requestWithHTTPAdditionalHeaders:[mAsset.configuration HTTPAdditionalHeadersForDataRequestsOfType:MCSDataTypeHLSPlaylist]] networkTaskPriority:mPriority delegate:self];
        [mTempParser prepare];
    }
}

#pragma mark - HLSAssetParserDelegate

- (void)parserParseDidFinish:(HLSAssetParser *)parser {
    @synchronized (self) {
        [self _createContentWithParser:parser];
    }
}

- (void)parser:(HLSAssetParser *)parser anErrorOccurred:(NSError *)error {
    [self abortWithError:error];
}

#pragma mark - mark

- (void)didAbortWithError:(NSError *)error {
    
}

#pragma mark - mark

/// unlocked
- (void)_createContentWithParser:(HLSAssetParser *)parser {
    switch ( self.status ) {
        case MCSReaderStatusFinished:
        case MCSReaderStatusAborted:
        case MCSReaderStatusReadyToRead:
            break;
        case MCSReaderStatusUnknown:
        case MCSReaderStatusPreparing: {
            if ( mAsset.parser == nil ) {
                mAsset.parser = parser;
            }
            
            NSString *filepath = mAsset.indexFilepath;
            UInt64 fileSize = (UInt64)[NSFileManager.defaultManager mcs_fileSizeAtPath:filepath];
            MCSAssetContent *content = [MCSAssetContent.alloc initWithFilepath:filepath startPositionInAsset:0 length:fileSize];
            [content readwriteRetain];
            [self contentDidReady:content range:NSMakeRange(0, fileSize)];
        }
            break;
    }
}
@end


