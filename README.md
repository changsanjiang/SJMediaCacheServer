
# SJMediaCacheServer

**SJMediaCacheServer** is an HTTP media caching framework designed to efficiently proxy playback requests and cache media content locally. This enables seamless media playback by serving cached content, thus reducing network load and improving playback performance. SJMediaCacheServer supports widely used media formats such as MP3, MP4, and HLS (m3u8) streaming resources.

Additionally, the framework provides robust cache management capabilities, allowing you to set limits on cache count, maximum disk storage time, and available disk space, ensuring optimal cache control and resource utilization.

With its powerful preloading feature, SJMediaCacheServer allows users to preload a specified number of bytes in advance, ensuring that the cached content is quickly accessible from the local server during playback.

## Installation
```ruby
pod 'SJUIKit/SQLite3', :podspec => 'https://gitee.com/changsanjiang/SJUIKit/raw/master/SJUIKit-YYModel.podspec'
pod 'SJMediaCacheServer'
```

# SJMediaCacheServer

**SJMediaCacheServer** is an HTTP media caching framework designed to efficiently proxy playback requests and cache media content locally. This enables seamless media playback by serving cached content, thus reducing network load and improving playback performance. SJMediaCacheServer supports widely used media formats such as MP3, MP4, and HLS (m3u8) streaming resources.

Additionally, the framework provides robust cache management capabilities, allowing you to set limits on cache count, maximum disk storage time, and available disk space, ensuring optimal cache control and resource utilization.

With its powerful preloading feature, SJMediaCacheServer allows users to preload a specified number of bytes in advance, ensuring that the cached content is quickly accessible from the local server during playback.

## Features

- **Proxy Playback Requests**: Efficiently proxy playback requests by converting original URLs into local proxy URLs. The media player retrieves the data from the local server, which serves cached data if available, or fetches it from the remote server if necessary. This mechanism reduces network usage and enhances playback speed and reliability.

- **Support for Multiple Media Formats**: Compatible with popular media formats, including:
    - MP3 (audio)
    - MP4 (video)
    - HLS (m3u8) streaming resources

- **Cache Management Options**:
    - **Cache Count Limits**: Control the number of items stored in the cache to avoid overuse of local storage.
    - **Maximum Disk Storage Time**: Configure how long items are retained in the cache before being purged, managing long-term storage effectively.
    - **Available Disk Space Limits**: Ensure the cache stays within a specified disk usage limit, preventing cache overflow from occupying too much local storage.

- **Advanced Prefetching Capabilities**:
    - **Concurrent Prefetching**: Use the `maxConcurrentPrefetchCount` property to control the maximum number of concurrent prefetch tasks, optimizing the preloading process without overwhelming system resources.
    - **Flexible Prefetching Methods**:
        - **Full Data Prefetching**: Use `prefetchWithURL:` to download all data related to a specific media asset, ensuring that the entire resource is available for playback without additional network requests.
        - **Size-Specific Prefetching**: With `prefetchWithURL:prefetchSize:`, request a predefined amount of data for partial prefetching. This is particularly useful for optimizing both bandwidth and storage while ensuring smooth playback.
        - **File Count Prefetching for HLS**: Leverage the `prefetchWithURL:prefetchFileCount:` method to prefetch a certain number of segment files for HLS assets. This ensures uninterrupted playback by caching multiple segments in advance, which is especially useful in low-bandwidth environments.

- **Custom Request Configuration**:
    - **Request Modification**: Modify outgoing requests by adding custom headers. Example:
        ```objc
        self.requestHandler = ^(NSMutableURLRequest *request) {
            [request addValue:@"YourHeaderValue" forHTTPHeaderField:@"YourHeaderField"];
        };
        ```

    - **Custom HTTP Headers**: Configure HTTP headers for specific asset URLs, such as HLS keys or segments. Example:
        ```objc
        [self setHTTPHeaderField:@"YourHeaderField" withValue:@"YourHeaderValue" forAssetURL:assetURL ofType:MCSDataTypeHLS];
        ```

    - **Data Encryption & Decryption**: Encrypt data before writing to the cache and decrypt after reading. Example:
        ```objc
        self.writeDataEncryptor = ^NSData *(NSURLRequest *request, NSUInteger offset, NSData *data) {
            return encryptedData; // Apply encryption
        };

        self.readDataDecryptor = ^NSData *(NSURLRequest *request, NSUInteger offset, NSData *data) {
            return decryptedData; // Apply decryption
        };
        ```

    - **Asset Type & Identifier Resolution**: Use custom logic to determine the asset type and identifier. Example:
        ```objc
        self.resolveAssetType = ^MCSAssetType(NSURL *URL) {
            return [URL.pathExtension isEqualToString:@"m3u8"] ? MCSAssetTypeHLS : MCSAssetTypeFILE;
        };

        self.resolveAssetIdentifier = ^NSString *(NSURL *URL) {
            return [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO].URL.absoluteString;
        };
        ```

## Example Use Case
```objc
@implementation YourPlayerController {
    AVPlayer *_player;
}

- (instancetype)initWithURL:(NSURL *)URL {
    self = [super init];
    if ( self ) {
        // Convert the original URL to a proxy URL
        NSURL *playbackURL = [SJMediaCacheServer.shared proxyURLFromURL:URL];
        _player = [AVPlayer playerWithURL:playbackURL];
    }
    return self;
}

- (void)play {
    [SJMediaCacheServer.shared setActive:YES];
    [_player play];
}

- (void)seekToTime:(NSTimeInterval)time {
    [SJMediaCacheServer.shared setActive:YES];
    [_player seekToTime:time];
}
@end

## License

SJMediaCacheServer is released under the MIT license.

## Feedback

- GitHub : [changsanjiang](https://github.com/changsanjiang)
- Email : changsanjiang@gmail.com
- QQGroup: 930508201

## Reference
- [KTVHTTPCache](https://github.com/ChangbaDevs/KTVHTTPCache) - KTVHTTPCache is a powerful media cache framework. It can cache HTTP request, and very suitable for media resources.

- https://tools.ietf.org/html/rfc7233#section-2.1
