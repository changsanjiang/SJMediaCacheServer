//
//  SJResourcePartialContent.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/2.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJResourcePartialContent.h"
#import "SJResource+SJPrivate.h"

@interface SJResourcePartialContent ()<NSLocking>
@property (nonatomic, strong) dispatch_semaphore_t semaphore;
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
        _semaphore = dispatch_semaphore_create(1);
        _name = name;
        _offset = offset;
        _length = length;
        _referenceCount = 1;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"SJResourcePartialContent: <%p> { name: %@, offset: %lu, length: %lu};", self, _name, _offset, self.length];
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
    BOOL changed = NO;
    [self lock];
    @try {
        if ( _referenceCount != referenceCount ) {
            _referenceCount = referenceCount;;
            changed = YES;
        }
    } @catch (__unused NSException *exception) {
        
    } @finally {
        [self unlock];
    }
    
    [self.delegate partialContent:self referenceCountDidChange:referenceCount];
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
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
}

- (void)unlock {
    dispatch_semaphore_signal(_semaphore);
}
@end
