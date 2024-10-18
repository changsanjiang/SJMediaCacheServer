//
//  HLSAssetDefines.h
//  Pods
//
//  Created by 畅三江 on 2021/7/19.
//

#ifndef HLSAssetDefines_h
#define HLSAssetDefines_h

#import "MCSAssetDefines.h"

NS_ASSUME_NONNULL_BEGIN
@protocol HLSAssetSegment <MCSAssetContent>
@property (nonatomic, readonly) UInt64 totalLength; // segment file totalLength or #EXT-X-BYTERANGE:1544984@1007868
@property (nonatomic, readonly) NSRange byteRange; // segment file {0, totalLength} or #EXT-X-BYTERANGE:1544984@1007868
@end
NS_ASSUME_NONNULL_END
#endif /* HLSAssetDefines_h */
