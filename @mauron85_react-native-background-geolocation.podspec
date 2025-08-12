Pod::Spec.new do |s|
  s.name         = "@mauron85_react-native-background-geolocation"
  s.version      = "0.6.999"
  s.summary      = "Background geolocation for React Native (fork with iOS significant-change option)"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.authors      = { "woosanggyu" => "example@example.com" }
  s.homepage     = "https://github.com/woosanggyu/react-native-background-geolocation"

  s.platform     = :ios, "11.0"
  s.requires_arc = true

  s.source       = { :path => "." }

  # 공통 소스 포함 (단, FMDB.*는 제외)
  s.source_files        = "ios/**/*.{h,m}", "ios/common/BackgroundGeolocation/**/*.{h,m}"
  s.public_header_files = "ios/**/*.{h}",   "ios/common/BackgroundGeolocation/**/*.{h}"
  s.exclude_files       = [
    "ios/common/BackgroundGeolocationTests/*.{h,m}",
    "ios/common/BackgroundGeolocation/FMDB.{h,m}"  # ★ FMDB 벤더링 소스 제외
  ]

  s.dependency "React-Core"
  s.dependency "FMDB", "~> 2.7.9"   # ★ 공식 FMDB에 의존
  s.frameworks = "CoreLocation", "UserNotifications"
end
