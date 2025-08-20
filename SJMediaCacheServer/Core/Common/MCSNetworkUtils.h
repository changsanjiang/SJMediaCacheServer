//
//  MCSNetworkUtils.h
//  SJMediaCacheServer
//
//  Created by changsanjiang@gmail.com on 2020/5/30.
//  Copyright © 2020 changsanjiang@gmail.com. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MCSNetworkUtils : NSObject

/// Get the device's local IP address for AirPlay support
/// This method returns the first available local IP address (preferably WiFi)
/// @return The device's local IP address, or nil if not available
+ (nullable NSString *)getLocalIPAddress;

/// Get the device's WiFi IP address specifically
/// @return The device's WiFi IP address, or nil if WiFi is not available
+ (nullable NSString *)getWiFiIPAddress;

/// Get all available local IP addresses
/// @return Array of available local IP addresses
+ (NSArray<NSString *> *)getAllLocalIPAddresses;

@end

NS_ASSUME_NONNULL_END
