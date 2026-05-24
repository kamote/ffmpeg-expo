require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'ExpoFFmpeg'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = package['license']
  s.author         = package['author']
  s.homepage       = 'https://github.com/kamote/ffmpeg-expo'
  s.platform       = :ios, '16.4'
  s.swift_version  = '5.9'
  s.source         = { :git => 'https://github.com/kamote/ffmpeg-expo.git', :tag => "v#{s.version}" }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  # Source files
  s.source_files = '**/*.{h,m,mm,swift}'
  s.exclude_files = 'Frameworks/**/*'
  s.public_header_files = 'FFmpegWrapper.h'
  s.private_header_files = 'FFmpeg.h'
  s.preserve_paths = 'Frameworks/**/*'

  # Required system frameworks
  s.frameworks = 'AudioToolbox', 'AVFoundation', 'CoreMedia', 'VideoToolbox', 'CoreVideo', 'CoreAudio'

  # System libraries
  s.libraries = 'z', 'bz2', 'iconv'

  # Build settings
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Frameworks/FFmpeg.xcframework/ios-arm64/Headers" "$(PODS_TARGET_SRCROOT)/Frameworks/FFmpeg.xcframework/ios-arm64_x86_64-simulator/Headers"',
    'LIBRARY_SEARCH_PATHS[sdk=iphoneos*]' => '"$(PODS_TARGET_SRCROOT)/Frameworks/FFmpeg.xcframework/ios-arm64"',
    'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]' => '"$(PODS_TARGET_SRCROOT)/Frameworks/FFmpeg.xcframework/ios-arm64_x86_64-simulator"',
    'OTHER_LDFLAGS' => '-lz -lbz2 -liconv -lffmpeg',
    'ENABLE_BITCODE' => 'NO'
  }

  # Link FFmpeg static library into app target
  ffmpeg_root = File.expand_path('Frameworks/FFmpeg.xcframework', __dir__)
  s.user_target_xcconfig = {
    'ENABLE_BITCODE' => 'NO',
    'LIBRARY_SEARCH_PATHS[sdk=iphoneos*]' => "$(inherited) \"#{ffmpeg_root}/ios-arm64\"",
    'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]' => "$(inherited) \"#{ffmpeg_root}/ios-arm64_x86_64-simulator\"",
    'OTHER_LDFLAGS' => '-lffmpeg'
  }
end
