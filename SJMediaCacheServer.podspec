#
# Be sure to run `pod lib lint SJMediaCacheServer.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SJMediaCacheServer'
  s.version          = '2.1.7'
  s.summary          = <<-DESC
  SJMediaCacheServer 是一个高效的 HTTP 媒体缓存框架，旨在代理媒体数据请求并优先提供缓存数据，从而减少网络流量并增强播放的流畅性。该框架支持两种类型的远程资源：基于文件的媒体，如 MP3、AAC、WAV、FLAC、OGG、MP4 和 MOV 等常见格式，以及 HLS（HTTP Live Streaming）流。它会自动解析 HLS 播放列表并代理各个媒体片段。
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
  end
  
  s.dependency 'SJUIKit/SQLite3'
  
  s.resource_bundles = {
   'SJMediaCacheServer' => ['SJMediaCacheServer/Assets/**/*']
  }
end
