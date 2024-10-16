//
//  MCSAssetContent.m
//  SJMediaCacheServer
//
//  Created by 畅三江 on 2021/7/19.
//

#import "MCSAssetContent.h"
#import "NSFileHandle+MCS.h"
#import "NSFileManager+MCS.h"
#import "MCSQueue.h"
#import "MCSUtils.h"
#import "MCSMimeType.h"
 
@implementation MCSAssetContent {
    NSString *mFilepath;
    UInt64 mLength;
    UInt64 mStartPositionInAsset;
    NSHashTable<id<MCSAssetContentObserver>> *_Nullable mObservers;
    
    NSFileHandle *_Nullable mWriter;
    NSFileHandle *_Nullable mReader;
}

- (instancetype)initWithMimeType:(NSString *)mimeType filepath:(NSString *)filepath startPositionInAsset:(UInt64)position length:(UInt64)length {
    self = [super init];
    if ( self ) {
        mFilepath = filepath;
        mStartPositionInAsset = position;
        mLength = length;
        _mimeType = mimeType;
    }
    return self;
}

- (instancetype)initWithFilepath:(NSString *)filepath startPositionInAsset:(UInt64)position length:(UInt64)length {
    return [self initWithMimeType:MCSMimeTypeFromFileAtPath(filepath) filepath:filepath startPositionInAsset:position length:length];
}

- (instancetype)initWithFilepath:(NSString *)filepath startPositionInAsset:(UInt64)position {
    return [self initWithFilepath:filepath startPositionInAsset:position length:0];
}

- (NSString *)description {
    @synchronized (self) {
        return [NSString stringWithFormat:@"%@: <%p> { startPosisionInAsset: %llu, lenth: %llu, readwriteCount: %ld, filepath: %@ };\n", NSStringFromClass(self.class), self, mStartPositionInAsset, mLength, (long)self.readwriteCount, mFilepath];
    }
}

- (void)dealloc {
    [self _closeWrite];
    [self _closeRead];
}

- (void)registerObserver:(id<MCSAssetContentObserver>)observer {
    if ( observer != nil ) {
        @synchronized (self) {
            if ( mObservers == nil ) mObservers = NSHashTable.weakObjectsHashTable;
            [mObservers addObject:observer];
        }
    }
}

- (void)removeObserver:(id<MCSAssetContentObserver>)observer {
    if ( observer != nil ) {
        @synchronized (self) {
            [mObservers removeObject:observer];
        }
    }
}

- (nullable NSData *)readDataAtPosition:(UInt64)posInAsset capacity:(UInt64)capacity error:(out NSError **)errorPtr {
    if ( posInAsset < mStartPositionInAsset )
        return nil;
    NSData *data = nil;
    NSError *error = nil;
    
    @synchronized (self) {
        UInt64 endPos = mStartPositionInAsset + mLength;
        if ( posInAsset >= endPos ) 
            return nil;
        
        // create reader
        if ( mReader == nil ) mReader = [NSFileHandle mcs_fileHandleForReadingFromURL:[NSURL fileURLWithPath:mFilepath] error:&error];
        
        // read data
        if ( mReader != nil ) {
            if ( [mReader mcs_seekToOffset:posInAsset - mStartPositionInAsset error:&error] ) {
                data = [mReader mcs_readDataUpToLength:capacity error:&error];
            }
        }
    }
    
    if ( error != nil && errorPtr != NULL) *errorPtr = error;
    return data;
}

- (UInt64)startPositionInAsset {
    return mStartPositionInAsset;
}

- (UInt64)length {
    @synchronized (self) {
        return mLength;
    }
}

#pragma mark - mark

- (BOOL)rewindWithError:(out NSError **)errorPtr {
    NSError *error = nil;
    NSArray<id<MCSAssetContentObserver>> *observers = nil;
    @try {
        @synchronized (self) {
            /// create writer
            if ( mWriter == nil ) {
                mWriter = [NSFileHandle mcs_fileHandleForWritingToURL:[NSURL fileURLWithPath:mFilepath] error:&error];
            }
            
            // rewind
            if ( mWriter != nil ) {
                if ( [mWriter mcs_rewindWithError:&error] ) {
                    mLength = 0;
                    observers = MCSAllHashTableObjects(self->mObservers);
                }
            }
        }
        if ( error != nil && errorPtr != NULL) *errorPtr = error;
        return error == nil;
    } 
    @finally {
        if ( observers != nil ) {
            for ( id<MCSAssetContentObserver> observer in observers) {
                [observer content:self didWriteDataWithLength:0];
            }
        }
    }
}

- (BOOL)writeData:(NSData *)data error:(out NSError **)errorPtr {
    UInt64 length = data.length;
    NSArray<id<MCSAssetContentObserver>> *observers = nil;
    NSError *error = nil;
    @try {
        @synchronized (self) {
            /// create writer
            if ( mWriter == nil ) {
                NSFileHandle *writer = [NSFileHandle mcs_fileHandleForWritingToURL:[NSURL fileURLWithPath:mFilepath] error:&error];
                if ( writer != nil ) {
                    if ( [writer mcs_seekToEndReturningOffset:NULL error:&error] ) {
                        mWriter = writer;
                    }
                    else {
                        [writer mcs_closeAndReturnError:NULL];
                    }
                }
            }
            
            // write data
            if ( mWriter != nil ) {
                if ( [mWriter mcs_writeData:data error:&error] ) {
                    mLength += length;
                    observers = MCSAllHashTableObjects(self->mObservers);
                }
            }
        }
        if ( error != nil && errorPtr != NULL) *errorPtr = error;
        return error == nil;
    } 
    @finally {
        if ( observers != nil ) {
            for ( id<MCSAssetContentObserver> observer in observers) {
                [observer content:self didWriteDataWithLength:length];
            }
        }
    }
}

///
/// 读取计数为0时才会生效
///
- (void)closeWrite {
    @synchronized (self) {
        if ( self.readwriteCount == 0 ) [self _closeWrite];
    }
}

///
/// 读取计数为0时才会生效
///
- (void)closeRead {
    @synchronized (self) {
        if ( self.readwriteCount == 0 ) [self _closeRead];
    }
}

///
/// 读取计数为0时才会生效
///
- (void)close {
    [self closeWrite];
    [self closeRead];
}

#pragma mark - unlocked

- (void)_closeRead {
    if ( mReader != nil ) {
        [mReader mcs_closeAndReturnError:NULL];
        mReader = nil;
    }
}

- (void)_closeWrite {
    if (mWriter != nil ) {
        [mWriter mcs_synchronizeAndReturnError:NULL];
        [mWriter mcs_closeAndReturnError:NULL];
        mWriter = nil;
    }
}
@end


@implementation MCSAssetContent (Internal)
- (NSString *)filepath {
    return mFilepath;
}
@end
