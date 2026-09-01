import Foundation

public struct AppVersion: Equatable, Sendable {
    public let shortVersion: String
    public let build: String

    public init(shortVersion: String, build: String) {
        self.shortVersion = shortVersion
        self.build = build
    }

    public init(bundle: Bundle = .main) {
        shortVersion = bundle.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0"
        build = bundle.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "1"
    }

    public var displayText: String {
        "\(shortVersion) (\(build))"
    }
}
