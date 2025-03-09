//
//  MCHttpRequest.m
//  SJMediaCacheServer
//
//  Created by 畅三江 on 2025/3/9.
//

#import "MCHttpRequest.h"
#import "MCSError.h"

@implementation NSString(MCAdditions)
- (NSString *)mc_trim {
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
@end


@implementation MCHttpRequest
+ (nullable instancetype)parseRequestWithData:(dispatch_data_t)data error:(NSError **)errorPtr {
    NSString *message = [NSString.alloc initWithData:(NSData *)data encoding:NSUTF8StringEncoding];
    if ( !message || message.length == 0 ) {
        if ( errorPtr ) {
            *errorPtr = [NSError mcs_errorWithCode:MCSInvalidRequestError userInfo:@{
                NSLocalizedDescriptionKey: @"Invalid request data."
            }];
        }
        return nil;
    }
    
    NSRange delimiterRange = [message rangeOfString:@"\r\n\r\n"];
    // 分离 header 部分和 body;
    NSString *headerPart = delimiterRange.length > 0 ? [[message substringToIndex:delimiterRange.location] mc_trim] : message;
    NSString *bodyPart = delimiterRange.length > 0 ? [[message substringFromIndex:NSMaxRange(delimiterRange)] mc_trim] : nil;
    
    // 不解析 body; 如果存在消息体部分, 直接退出;
    if ( bodyPart.length > 0 ) {
        if ( errorPtr ) {
            *errorPtr = [NSError mcs_errorWithCode:MCSInvalidRequestError userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Request '%@' contains a body, which is not supported", message]
            }];
        }
        return nil;
    }
    
    // https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Messages
    // https://datatracker.ietf.org/doc/html/rfc9110#name-host-and-authority
    //
    // GET /pub/WWW/ HTTP/1.1
    // Host: www.example.org
    //
    NSArray<NSString *> *headerLines = [headerPart componentsSeparatedByString:@"\r\n"];
    
    // 解析起始行
    NSString *startLine = headerLines.firstObject;
    
    // 分割起始行，获取 method, requestTarget, 和 httpVersion
    NSArray<NSString *> *startLineParts = [startLine componentsSeparatedByString:@" "];
    if ( startLineParts.count != 3 ) {
        if ( errorPtr ) {
            *errorPtr = [NSError mcs_errorWithCode:MCSInvalidRequestError userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Invalid start line format: '%@'.", startLine]
            }];
        }
        return nil;
    }
    
    NSString *method = startLineParts[0];
    NSString *requestTarget = startLineParts[1];
    NSString *httpVersion = startLineParts[2];
    if ( ![httpVersion isEqualToString:@"HTTP/1.1"] ) {
        if ( errorPtr ) {
            *errorPtr = [NSError mcs_errorWithCode:MCSInvalidRequestError userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unsupported HTTP version: '%@', Only HTTP/1.1 is supported", httpVersion]
            }];
        }
        return nil;
    }
    
    // 仅支持 GET 和 HEAD 方法
    if ( ![method isEqualToString:@"GET"] && ![method isEqualToString:@"HEAD"] ) {
        if ( errorPtr ) {
            *errorPtr = [NSError mcs_errorWithCode:MCSInvalidRequestError userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unsupported HTTP method: '%@', Only GET and HEAD are supported", method]
            }];
        }
        return nil;
    }
    
    // 解析剩余的头部字段
    NSMutableDictionary<NSString *, NSString *> *headers = NSMutableDictionary.dictionary;
    for ( int i = 1 ; i < headerLines.count ; ++ i ) {
        NSString *line = headerLines[i];
        NSRange separatorIndex = [line rangeOfString:@":"];
        if ( separatorIndex.length == 0 ) {
            NSLog(@"Invalid header line: %@", line);
            if ( errorPtr ) {
                *errorPtr = [NSError mcs_errorWithCode:MCSInvalidRequestError userInfo:@{
                    NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Invalid header line: '%@'.", line]
                }];
            }
            continue;
        }
        
        NSString *key = [[line substringToIndex:separatorIndex.location] mc_trim];
        NSString *value = [[line substringFromIndex:NSMaxRange(separatorIndex)] mc_trim];
        headers[key] = value;
    }
    
    return [MCHttpRequest.alloc initWithRawMessage:message method:method requestTarget:requestTarget headers:headers];
}

- (instancetype)initWithRawMessage:(NSString *)rawMessage method:(NSString *)method requestTarget:(NSString *)requestTarget headers:(NSDictionary<NSString *, NSString *> *)headers {
    self = [super init];
    _rawMessage = rawMessage;
    _method = method;
    _requestTarget = requestTarget;
    _headers = headers;
    return self;
}
@end
