//
//  MCSResourceNetworkDataReader.h
//  Pods
//
//  Created by BlueDancer on 2020/8/5.
//

#import "MCSResourceDataReader.h"

NS_ASSUME_NONNULL_BEGIN
@interface MCSResourceNetworkDataReader : MCSResourceDataReader

- (instancetype)initWithResource:(__weak MCSResource *)resource request:(NSURLRequest *)request networkTaskPriority:(float)networkTaskPriority delegate:(id<MCSResourceDataReaderDelegate>)delegate;

@end
NS_ASSUME_NONNULL_END
