Pod::Spec.new do |s|
  s.name = 'BioScanAnalytics'
  s.version = '0.1.8'
  s.summary = 'Shared PostHog analytics for BioScan apps.'
  s.homepage = 'https://github.com/benzhipeng/BioScanKit-iOS'
  s.license = { :type => 'Proprietary' }
  s.author = { 'benzhipeng' => 'benzhipeng' }
  s.source = { :git => 'https://github.com/benzhipeng/BioScanKit-iOS.git', :tag => s.version.to_s }
  s.ios.deployment_target = '18.0'
  s.swift_version = '5.9'
  s.source_files = 'Sources/BioScanAnalytics/**/*.swift'
  s.frameworks = 'Foundation', 'UIKit'
  s.dependency 'PostHog', '~> 3.84.1'
end
