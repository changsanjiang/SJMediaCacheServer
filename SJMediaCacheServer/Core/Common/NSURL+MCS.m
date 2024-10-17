//
//  NSURL+MCS.m
//  SJMediaCacheServer
//
//  Created by db on 2024/10/17.
//

#import "NSURL+MCS.h"

@implementation NSURL (MCS)
- (NSURL *)mcs_URLByAppendingPathComponent:(NSString *)pathComponent {
    if ( [pathComponent isEqualToString:@"/"] )
        return self;
    NSString *url = self.absoluteString;
    while ( [url hasSuffix:@"/"] ) url = [url substringToIndex:url.length - 1];
    NSString *path = pathComponent;
    while ( [path hasPrefix:@"/"] ) path = [path substringFromIndex:1];
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", url, path]];
}

- (NSURL *)mcs_URLByRemovingLastPathComponentAndQuery {
    NSString *query = self.query;
    if ( query.length != 0 ) {
        NSString *absoluteString = self.absoluteString;
        NSString *url = [absoluteString substringToIndex:absoluteString.length - query.length - 1];
        return [NSURL URLWithString:url].URLByDeletingLastPathComponent;
    }
    return self.URLByDeletingLastPathComponent;
}
@end
