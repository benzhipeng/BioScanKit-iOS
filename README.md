# BioScanKit iOS

Native SwiftUI components shared by the BioScan app family, distributed through CocoaPods.

## Modules

- `BioScanDesign`: adaptive themes, colors, and navigation styles.
- `BioScanSettings`: settings screens, rows, membership UI, and recommended apps.
- `BioScanCapture`: camera composition, crop editing, image processing, and recognition flows.
- `BioScanPaywall`: paywall UI, billing abstractions, credit ledger, and purchase recovery.
- `BioScanCloudSync`: cloud-favorite snapshots and synchronization.
- `BioScanKit`: aggregate product containing all modules.

Host apps own recognition engines, navigation, analytics, credentials, product identifiers, persistence, and branded assets.

## CocoaPods integration

```ruby
pod 'BioScanDesign', :git => 'https://github.com/benzhipeng/BioScanKit-iOS.git', :tag => '0.1.0'
pod 'BioScanCloudSync', :git => 'https://github.com/benzhipeng/BioScanKit-iOS.git', :tag => '0.1.0'
pod 'BioScanSettings', :git => 'https://github.com/benzhipeng/BioScanKit-iOS.git', :tag => '0.1.0'
pod 'BioScanCapture', :git => 'https://github.com/benzhipeng/BioScanKit-iOS.git', :tag => '0.1.0'
pod 'BioScanPaywall', :git => 'https://github.com/benzhipeng/BioScanKit-iOS.git', :tag => '0.1.0'
```

Declare only the modules needed by the host app, then run `pod install` and open the generated workspace.

Shared recommendation data and icons live in `Shared/`. The `Scripts/copy_app_recommendations.sh` helper copies them into an app bundle during an Xcode build.

## Validation

```sh
pod spec lint BioScanDesign.podspec --allow-warnings
```
