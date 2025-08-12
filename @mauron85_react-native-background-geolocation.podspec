Pod::Spec.new do |s|
  s.name         = "@mauron85_react-native-background-geolocation"
  s.version      = "0.6.999"
  s.platform     = :ios, "11.0"
  s.requires_arc = true

  s.source       = { :git => "https://github.com/woosanggyu/react-native-background-geolocation.git", :branch => "master" }

  # iOS 소스 전부 포함(+ 우리가 벤더링한 common 폴더)
  s.source_files = "ios/**/*.{h,m}"
  s.public_header_files = "ios/**/*.{h}"

  s.dependency "React-Core"
  s.frameworks = "CoreLocation"
end
