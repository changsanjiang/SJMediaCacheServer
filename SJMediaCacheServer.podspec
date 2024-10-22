#
# Be sure to run `pod lib lint SJMediaCacheServer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SJMediaCacheServer'
  s.version          = '2.0.0'
  s.summary          = <<-DESC
  SJMediaCacheServer is an HTTP media caching framework designed to efficiently proxy playback requests and cache media content locally. This enables seamless media playback by serving cached content, thus reducing network load and improving playback performance. SJMediaCacheServer supports widely used media formats such as MP3, MP4, and HLS (m3u8) streaming resources.

  Additionally, the framework provides robust cache management capabilities, allowing you to set limits on cache count, maximum disk storage time, and available disk space, ensuring optimal cache control and resource utilization.

  With its powerful preloading feature, SJMediaCacheServer allows users to preload a specified number of bytes in advance, ensuring that the cached content is quickly accessible from the local server during playback.
  DESC

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = 'https://github.com/changsanjiang/SJMediaCacheServer/blob/master/README.md'

  s.homepage         = 'https://github.com/changsanjiang/SJMediaCacheServer'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'changsanjiang' => 'changsanjiang@gmail.com' }
  s.source           = { :git => 'https://github.com/changsanjiang/SJMediaCacheServer.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '12.0'

  s.source_files = 'SJMediaCacheServer/*.{h,m}'
  s.subspec 'Core' do |ss|
    ss.source_files = 'SJMediaCacheServer/Core/**/*.{h,m}'
    ss.dependency 'SJMediaCacheServer/KTVCocoaHTTPServer'
  end
  
  s.subspec 'KTVCocoaHTTPServer' do |ss|
    ss.source_files = 'SJMediaCacheServer/KTVCocoaHTTPServer/**/*.{h,m}'
    ss.dependency 'CocoaAsyncSocket'
  end
  
  s.dependency 'SJUIKit/SQLite3'
  
  s.resource_bundles = {
   'SJMediaCacheServer' => ['SJMediaCacheServer/Assets/**/*']
  }
end
