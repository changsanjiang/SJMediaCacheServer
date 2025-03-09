//
//  MCHttpRequest.h
//  SJMediaCacheServer
//
//  Created by 畅三江 on 2025/3/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
// https://developer.mozilla.org/zh-CN/docs/Web/HTTP/Messages
// https://datatracker.ietf.org/doc/html/rfc9110#name-host-and-authority
//
// GET /pub/WWW/ HTTP/1.1
// Host: www.example.org
//
@interface MCHttpRequest : NSObject
/**
 * 解析原始 HTTP 请求消息，仅处理 GET 和 HEAD 请求。
 *
 * @param data - 原始 HTTP 请求数据
 * @returns IMCHttpRequest - 解析后的 HTTP 请求对象, 解析失败
 *
 */
+ (nullable instancetype)parseRequestWithData:(dispatch_data_t)data error:(NSError **)error;
@property (nonatomic, strong, readonly) NSString *rawMessage;
@property (nonatomic, strong, readonly) NSString *method; // 请求方法 (如 GET, HEAD)
@property (nonatomic, strong, readonly) NSString *requestTarget; // 请求目标 (如 "/index.html")
@property (nonatomic, strong, readonly) NSDictionary<NSString *, NSString *> *headers; // 所有的请求头字段;
@end
NS_ASSUME_NONNULL_END
