//
//  MCSNetworkUtils.m
//  SJMediaCacheServer
//
//  Created by changsanjiang@gmail.com on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "MCSNetworkUtils.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>

@implementation MCSNetworkUtils

+ (nullable NSString *)getLocalIPAddress {
    // First try to get WiFi IP address
    NSString *wifiIP = [self getWiFiIPAddress];
    if (wifiIP) {
        return wifiIP;
    }

    // If WiFi is not available, get the first available local IP
    NSArray<NSString *> *allIPs = [self getAllLocalIPAddresses];
    return allIPs.firstObject;
}

+ (nullable NSString *)getWiFiIPAddress {
    NSArray<NSString *> *allIPs = [self getAllLocalIPAddresses];

    // Look for WiFi interface (en0 on iOS)
    for (NSString *ip in allIPs) {
        if ([ip hasPrefix:@"192.168."] || [ip hasPrefix:@"10."] || [ip hasPrefix:@"172."]) {
            return ip;
        }
    }

    return nil;
}

+ (NSArray<NSString *> *)getAllLocalIPAddresses {
    NSMutableArray<NSString *> *ipAddresses = [NSMutableArray array];

    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;

    // Retrieve the current interfaces - returns 0 on success
    int success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if (temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 (WiFi) or en1 (Cellular)
                NSString *interfaceName = [NSString stringWithUTF8String:temp_addr->ifa_name];
                if ([interfaceName isEqualToString:@"en0"] ||
                    [interfaceName isEqualToString:@"en1"] ||
                    [interfaceName isEqualToString:@"en2"] ||
                    [interfaceName isEqualToString:@"en3"]) {

                    // Get IP address
                    char ip[INET_ADDRSTRLEN];
                    inet_ntop(AF_INET, &(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr), ip, INET_ADDRSTRLEN);
                    NSString *ipString = [NSString stringWithUTF8String:ip];

                    // Skip localhost
                    if (![ipString isEqualToString:@"127.0.0.1"] && ![ipString isEqualToString:@"::1"]) {
                        [ipAddresses addObject:ipString];
                    }
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }

    // Free memory
    freeifaddrs(interfaces);

    return [ipAddresses copy];
}

@end
