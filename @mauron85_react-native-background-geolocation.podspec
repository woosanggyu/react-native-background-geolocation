Pod::Spec.new do |s|
  s.name         = "@mauron85_react-native-background-geolocation"
  s.version      = "0.6.999"
  s.summary      = "Background geolocation for React Native (fork with iOS significant-change option)"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.authors      = { "woosanggyu" => "example@example.com" }
  s.homepage     = "https://github.com/woosanggyu/react-native-background-geolocation"

  s.platform     = :ios, "11.0"
  s.requires_arc = true

  # 로컬 경로(= node_modules/패키지 내부) 기준
  s.source       = { :path => "." }

  # 공통 소스 포함(여기에 MAURProviderDelegate.h 등이 있어야 함)
  s.source_files        = "ios/**/*.{h,m}", "ios/common/BackgroundGeolocation/**/*.{h,m}"
  s.public_header_files = "ios/**/*.{h}",   "ios/common/BackgroundGeolocation/**/*.{h}"
  s.exclude_files       = "ios/common/BackgroundGeolocationTests/*.{h,m}"

  s.dependency "React-Core"
  s.frameworks = "CoreLocation", "UserNotifications"
end
