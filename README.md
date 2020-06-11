
# SJMediaCacheServer

```ruby
pod 'SJMediaCacheServer'
```

___

# Usage

```Objective-C
#import <SJMediaCacheServer/SJMediaCacheServer.h>

    NSURL *URL = [NSURL URLWithString:@"http://.../auido.mp3"];
    NSURL *playbackURL = [SJMediaCacheServer.shared playbackURLWithURL:URL];
    AVPlayer *player = [AVPlayer playerWithURL:playbackURL];
    [player play];
```
