//
//  SJResourcePartialContent.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourcePartialContent.h"
#import "SJResource+SJPrivate.h"

@interface SJResourcePartialContent ()<NSLocking> {
    NSRecursiveLock *_lock;
}
@property (nonatomic, weak, nullable) id<SJResourcePartialContentDelegate> delegate;
@property NSInteger referenceCount;

- (void)reference_retain;
- (void)reference_release;
@end

@implementation SJResourcePartialContent
- (instancetype)initWithName:(NSString *)name offset:(NSUInteger)offset {
    return [self initWithName:name offset:offset length:0];
}

- (instancetype)initWithName:(NSString *)name offset:(NSUInteger)offset length:(NSUInteger)length {
    self = [super init];
    if ( self ) {
        _lock = NSRecursiveLock.alloc.init;
        _name = name;
        _offset = offset;
        _length = length;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"SJResourcePartialContent: <%p> { name: %@, offset: %lu, length: %lu };", self, _name, _offset, self.length];
}

@synthesize length = _length;
- (void)setLength:(NSUInteger)length {
    [self lock];
    @try {
        _length = length;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSUInteger)length {
    [self lock];
    @try {
        return _length;;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

@synthesize referenceCount = _referenceCount;
- (void)setReferenceCount:(NSInteger)referenceCount {
    [self lock];
    @try {
        if ( _referenceCount != referenceCount ) {
            _referenceCount = referenceCount;;
            
            [_delegate referenceCountDidChangeForPartialContent:self];
        }
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}

- (NSInteger)referenceCount {
    [self lock];
    @try {
        return _referenceCount;;
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
}
 
- (void)reference_retain {
    self.referenceCount += 1;
}

- (void)reference_release {
    self.referenceCount -= 1;
}

- (void)lock {
    [_lock lock];
}

- (void)unlock {
    [_lock unlock];
}
@end
