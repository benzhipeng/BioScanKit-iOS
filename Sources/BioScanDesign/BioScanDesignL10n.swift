import Foundation

enum BioScanDesignL10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, value: key, comment: "")
    }

    private static let bundle: Bundle = {
        let bundleName = "BioScanDesignResources"
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
