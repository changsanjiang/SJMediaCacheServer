//
//  MCSReadwrite.m
//  SJMediaCacheServer
//
//  Created by 畅三江 on 2021/7/19.
//

#import "MCSReadwrite.h"
#import "MCSConsts.h"

@implementation MCSReadwrite {
    NSInteger mReadwriteCount;
}

#ifdef DEBUG
- (void)dealloc {
    if ( mReadwriteCount != 0 ) {
        NSLog(@"%@<%p>: %d : %s; waring: readwrite retained.", NSStringFromClass(self.class), self, __LINE__, sel_getName(_cmd));
    }
}
#endif

- (NSInteger)readwriteCount {
    @synchronized (self) {
        return mReadwriteCount;
    }
}

- (instancetype)readwriteRetain {
    @synchronized (self) {
        mReadwriteCount += 1;
        [self readwriteCountDidChange:mReadwriteCount];
    }
    return self;
}

- (void)readwriteRelease {
    @synchronized (self) {
        if ( mReadwriteCount > 0 ) {
            mReadwriteCount -= 1;
            [self readwriteCountDidChange:mReadwriteCount];
        }
#ifdef DEBUG
        else {
            NSLog(@"%@<%p>: %d : %s; waring: readwriteRelease was overcalled.", NSStringFromClass(self.class), self, __LINE__, sel_getName(_cmd));
        }
#endif
    }
}

- (void)readwriteCountDidChange:(NSInteger)count {}
@end
