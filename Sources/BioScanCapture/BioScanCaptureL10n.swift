import Foundation
import BioScanDesign

enum BioScanCaptureL10n {
    static func string(_ key: String) -> String {
        BioScanLocalization.shared.string(key, bundle: bundle)
    }

    private static let bundle: Bundle = {
        let bundleName = "BioScanCaptureResources"
        let candidates = [
            Bundle.main.url(forResource: bundleName, withExtension: "bundle"),
            Bundle(for: BundleToken.self).url(forResource: bundleName, withExtension: "bundle")
        ]

        for url in candidates {
            if let url, let bundle = Bundle(url: url) {
                return bundle
            }
        }

        return Bundle(for: BundleToken.self)
    }()
}

private final class BundleToken {}
