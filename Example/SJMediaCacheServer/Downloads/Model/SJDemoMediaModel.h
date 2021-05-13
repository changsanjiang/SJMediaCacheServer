//
//  SJDemoMediaModel.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2021/5/13.
//  Copyright © 2021 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SJDemoMediaModel : NSObject
- (instancetype)initWithId:(NSInteger)id name:(NSString *)name url:(NSString *)url;
@property (nonatomic) NSInteger id;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *url;
@end

NS_ASSUME_NONNULL_END
