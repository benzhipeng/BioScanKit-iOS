Pod::Spec.new do |s|
  s.name = 'BioScanSettings'
  s.version = '0.1.1'
  s.summary = 'Shared settings UI for BioScan apps.'
  s.homepage = 'https://github.com/benzhipeng/BioScanKit-iOS'
  s.license = { :type => 'Proprietary' }
  s.author = { 'benzhipeng' => 'benzhipeng' }
  s.source = { :git => 'https://github.com/benzhipeng/BioScanKit-iOS.git', :tag => s.version.to_s }
  s.ios.deployment_target = '18.0'
  s.swift_version = '5.9'
  s.source_files = 'Sources/BioScanSettings/**/*.swift'
  s.resource_bundles = { 'BioScanSettingsResources' => ['Sources/BioScanSettings/Resources/**/*'] }
  s.resources = ['Shared/RecommendedApps.json', 'Shared/Icons/*.png']
  s.frameworks = 'SwiftUI', 'UIKit'
  s.dependency 'BioScanDesign', s.version.to_s
  s.dependency 'BioScanCloudSync', s.version.to_s
end
