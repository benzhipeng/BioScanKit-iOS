Pod::Spec.new do |s|
  s.name = 'BioScanCapture'
  s.version = '0.1.0'
  s.summary = 'Shared camera and recognition flows for BioScan apps.'
  s.homepage = 'https://github.com/benzhipeng/BioScanKit-iOS'
  s.license = { :type => 'Proprietary' }
  s.author = { 'benzhipeng' => 'benzhipeng' }
  s.source = { :git => 'https://github.com/benzhipeng/BioScanKit-iOS.git', :tag => s.version.to_s }
  s.ios.deployment_target = '18.0'
  s.swift_version = '5.9'
  s.source_files = 'Sources/BioScanCapture/**/*.swift'
  s.frameworks = 'AVFoundation', 'CoreImage', 'ImageIO', 'PhotosUI', 'SwiftUI', 'UIKit'
  s.dependency 'BioScanDesign', s.version.to_s
end
