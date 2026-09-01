# BioScanKit iOS

Native SwiftUI components shared by the BioScan app family.

## Modules

- `BioScanDesign`: adaptive themes, colors, and navigation styles.
- `BioScanSettings`: settings screens, rows, membership UI, and recommended apps.
- `BioScanCapture`: camera composition, crop editing, image processing, and recognition flows.
- `BioScanPaywall`: paywall UI, billing abstractions, credit ledger, and purchase recovery.
- `BioScanCloudSync`: cloud-favorite snapshots and synchronization.
- `BioScanKit`: aggregate product containing all modules.

Host apps own recognition engines, navigation, analytics, credentials, product identifiers, persistence, and branded assets.

## Local integration

```yaml
packages:
  BioScanKit:
    path: ../../BioScanKit-iOS
```

Shared recommendation data and icons live in `Shared/`. The `Scripts/copy_app_recommendations.sh` helper copies them into an app bundle during an Xcode build.

## Build

```sh
xcodebuild \
  -scheme BioScanKit \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/BioScanKit-DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```
