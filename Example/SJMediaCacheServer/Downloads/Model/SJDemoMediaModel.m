//
//  SJDemoMediaModel.m
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/5/13.
//  Copyright © 2021 changsanjiang@gmail.com. All rights reserved.
//

#import "SJDemoMediaModel.h"

@implementation SJDemoMediaModel
- (instancetype)initWithId:(NSInteger)id name:(NSString *)name url:(NSString *)url {
    self = [super init];
    if ( self ) {
        _id = id;
        _name = name;
        _url = url;
    }
    return self;
}
@end
