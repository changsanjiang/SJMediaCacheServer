//
//  MCSHLSDataReader.h
//  SJMediaCacheServer
//
//  Created by BlueDancer on 2020/6/10.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#ifndef MCSHLSDataReader_h
#define MCSHLSDataReader_h
#import "MCSResourceDefines.h"
@protocol MCSResourceResponse;

NS_ASSUME_NONNULL_BEGIN
@protocol MCSHLSDataReader <MCSResourceDataReader>
@property (nonatomic, strong, readonly, nullable) id<MCSResourceResponse> response;
@end
NS_ASSUME_NONNULL_END
#endif /* MCSHLSDataReader_h */
