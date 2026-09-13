import Foundation
import Observation

enum BioScanDesignL10n {
    static func string(_ key: String) -> String {
        BioScanLocalization.shared.string(key, bundle: bundle)
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

// Observable reads made while rendering keep localized component views up to date.
@Observable
public final class BioScanLocalization {
    public static let shared = BioScanLocalization()
    public var languageIdentifier = ""

    public var locale: Locale {
        languageIdentifier.isEmpty ? .autoupdatingCurrent : Locale(identifier: languageIdentifier)
    }

    public func string(_ key: String, bundle: Bundle = .main) -> String {
        let language = languageIdentifier
        let sentinel = "__bioscan_missing_translation__"
        let bundles = bundle == .main ? [bundle] : [bundle, .main]
        if language.isEmpty {
            for source in bundles {
                let value = source.localizedString(forKey: key, value: sentinel, table: nil)
                if value != sentinel { return value }
            }
        } else {
            for identifier in [language, "en"] {
                for source in bundles {
                    guard let path = source.path(forResource: identifier, ofType: "lproj"),
                          let localized = Bundle(path: path) else { continue }
                    let value = localized.localizedString(forKey: key, value: sentinel, table: nil)
                    if value != sentinel { return value }
                }
            }
        }
        return key
    }
}
