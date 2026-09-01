// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BioScanKit",
    platforms: [
        .iOS("18.0")
    ],
    products: [
        .library(name: "BioScanDesign", targets: ["BioScanDesign"]),
        .library(name: "BioScanCloudSync", targets: ["BioScanCloudSync"]),
        .library(name: "BioScanSettings", targets: ["BioScanSettings"]),
        .library(name: "BioScanCapture", targets: ["BioScanCapture"]),
        .library(name: "BioScanPaywall", targets: ["BioScanPaywall"]),
        .library(
            name: "BioScanKit",
            targets: [
                "BioScanDesign",
                "BioScanCloudSync",
                "BioScanSettings",
                "BioScanCapture",
                "BioScanPaywall"
            ]
        )
    ],
    targets: [
        .target(name: "BioScanDesign"),
        .target(name: "BioScanCloudSync"),
        .target(
            name: "BioScanSettings",
            dependencies: ["BioScanDesign", "BioScanCloudSync"]
        ),
        .target(
            name: "BioScanCapture",
            dependencies: ["BioScanDesign"]
        ),
        .target(
            name: "BioScanPaywall",
            dependencies: ["BioScanDesign"]
        ),
        .testTarget(
            name: "BioScanCaptureTests",
            dependencies: ["BioScanCapture"]
        ),
        .testTarget(
            name: "BioScanPaywallTests",
            dependencies: ["BioScanPaywall"]
        ),
        .testTarget(
            name: "BioScanSettingsTests",
            dependencies: ["BioScanSettings"]
        ),
        .testTarget(
            name: "BioScanCloudSyncTests",
            dependencies: ["BioScanCloudSync"]
        )
    ]
)
