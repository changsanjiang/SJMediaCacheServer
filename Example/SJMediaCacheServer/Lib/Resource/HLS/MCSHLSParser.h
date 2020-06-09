//
//  MCSHLSParser.h
//  SJMediaCacheServer_Example
//
//  Created by BlueDancer on 2020/6/9.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>
@protocol MCSHLSParserDelegate;

NS_ASSUME_NONNULL_BEGIN

@interface MCSHLSParser : NSObject
- (instancetype)initWithURL:(NSURL *)URL delegate:(id<MCSHLSParserDelegate>)delegate;

- (void)prepare;

- (void)close;

@property (nonatomic, readonly) BOOL isClosed;
@property (nonatomic, readonly) BOOL isDone;

@property (nonatomic, copy, readonly, nullable) NSArray<NSURL *> *tsArray;
@end


@protocol MCSHLSParserDelegate <NSObject>
- (NSString *)AESKeyWritePathForParser:(MCSHLSParser *)parser;
- (NSString *)tsURLArrayWritePathForParser:(MCSHLSParser *)parser;
- (NSString *)indexFileWritePathForParser:(MCSHLSParser *)parser;
- (NSString *)parser:(MCSHLSParser *)parser tsFilenameForUrl:(NSString *)url;

- (void)parserParseDidFinish:(MCSHLSParser *)parser;
- (void)parser:(MCSHLSParser *)parser anErrorOccurred:(NSError *)error;
@end

NS_ASSUME_NONNULL_END
