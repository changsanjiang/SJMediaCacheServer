//
//  MCSResourceDataReaderSubclass.h
//  Pods
//
//  Created by BlueDancer on 2020/8/5.
//

#import "MCSResourceDataReader.h"
#import "MCSQueue.h"
#import "MCSLogger.h"
#import "MCSError.h"

@interface MCSResourceDataReader (Subclass)

- (instancetype)initWithResource:(MCSResource *)resource delegate:(id<MCSResourceDataReaderDelegate>)delegate;

- (void)_onError:(NSError *)error;

- (void)_close;

- (void)_prepare;

@end
