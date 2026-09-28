import Foundation
import PostHog

public protocol AnalyticsEventName {
    var analyticsName: String { get }
}

public extension AnalyticsEventName where Self: RawRepresentable, RawValue == String {
    var analyticsName: String { rawValue }
}

public struct AnalyticsConfiguration: Sendable {
    public let projectToken: String
    public let host: String
    public let appID: String
    public let appName: String
    public let environment: String
    public let debug: Bool
    public let capturesAutomaticScreenViews: Bool
    public let sessionReplayEnabled: Bool

    public init(
        projectToken: String,
        host: String,
        appID: String,
        appName: String,
        environment: String,
        debug: Bool = false,
        capturesAutomaticScreenViews: Bool = false,
        sessionReplayEnabled: Bool = false
    ) {
        self.projectToken = projectToken
        self.host = host
        self.appID = appID
        self.appName = appName
        self.environment = environment
        self.debug = debug
        self.capturesAutomaticScreenViews = capturesAutomaticScreenViews
        self.sessionReplayEnabled = sessionReplayEnabled
    }

    public static func postHogDefault(
        appID: String,
        appName: String,
        debug: Bool = false,
        capturesAutomaticScreenViews: Bool = false,
        sessionReplayEnabled: Bool = false
    ) -> AnalyticsConfiguration {
        AnalyticsConfiguration(
            projectToken: "phc_y4fqG9tbNmvjrbUvXRQuigkMuiaqWkFothJJM7MWFPAz",
            host: "https://us.i.posthog.com",
            appID: appID,
            appName: appName,
            environment: debug ? "debug" : "app_store",
            debug: debug,
            capturesAutomaticScreenViews: capturesAutomaticScreenViews,
            sessionReplayEnabled: sessionReplayEnabled
        )
    }
}

public enum BioScanAnalytics {
    private static let lock = NSLock()
    private static var configured = false
    private static var paywallSessionID: String?
    private static var purchaseAttemptID: String?
    private static var paywallContext: [String: Any] = [:]
    private static var paywallCompletedSuccessfully = false

    public static func configure(_ configuration: AnalyticsConfiguration) {
        guard !configuration.projectToken.isEmpty, !configuration.host.isEmpty, !configuration.appID.isEmpty else {
            return
        }

        lock.lock()
        defer { lock.unlock() }
        guard !configured else { return }

        let config = PostHogConfig(projectToken: configuration.projectToken, host: configuration.host)
        config.debug = configuration.debug
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = configuration.capturesAutomaticScreenViews
        config.captureElementInteractions = false
        config.sessionReplay = configuration.sessionReplayEnabled
        if configuration.sessionReplayEnabled {
            config.sessionReplayConfig.screenshotMode = true
            config.sessionReplayConfig.maskAllTextInputs = true
            config.sessionReplayConfig.maskAllImages = true
            config.sessionReplayConfig.maskAllSandboxedViews = true
        }

        let protectedProperties: [String: Any] = [
            "app_id": configuration.appID,
            "app_name": configuration.appName,
            "bundle_id": Bundle.main.bundleIdentifier ?? "unknown",
            "app_version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            "build_number": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            "environment": configuration.environment,
            "device_locale": Locale.current.identifier
        ]

        config.setBeforeSend { event in
            for (key, value) in protectedProperties {
                event.properties[key] = value
            }
            if event.properties["platform"] == nil {
                event.properties["platform"] = "ios"
            }
            return event
        }

        PostHogSDK.shared.setup(config)
        PostHogSDK.shared.register(
            protectedProperties.merging(["platform": "ios"]) { current, _ in current }
        )
        configured = true
    }

    public static func track(_ event: some AnalyticsEventName, properties: [String: Any] = [:]) {
        track(event.analyticsName, properties: properties)
    }

    public static func track(_ eventName: String, properties: [String: Any] = [:]) {
        guard !eventName.isEmpty else { return }
        let canonicalName = eventName == "paywall_show" ? "paywall_shown" : eventName
        guard let properties = sanitize(properties, eventName: canonicalName) else { return }
        PostHogSDK.shared.capture(canonicalName, properties: properties)
    }

    public static func screen(_ name: String, properties: [String: Any] = [:]) {
        guard !name.isEmpty else { return }
        PostHogSDK.shared.screen(name, properties: sanitize(properties) ?? [:])
    }

    public static func identify(userID: String, properties: [String: Any] = [:]) {
        guard !userID.isEmpty else { return }
        PostHogSDK.shared.identify(userID, userProperties: sanitize(properties) ?? [:])
    }

    public static func reset() {
        PostHogSDK.shared.reset()
    }

    public static func setTrackingEnabled(_ enabled: Bool) {
        if enabled {
            PostHogSDK.shared.optIn()
        } else {
            PostHogSDK.shared.optOut()
        }
    }

    public static func flush() {
        PostHogSDK.shared.flush()
    }

    private static func sanitize(_ properties: [String: Any], eventName: String? = nil) -> [String: Any]? {
        var normalized = properties
        if normalized["product_id"] == nil, let product = normalized["product"] {
            normalized["product_id"] = product
        }
        if normalized["entitlement_state"] == nil, let tier = normalized["membership_tier"] {
            normalized["entitlement_state"] = tier
        }
        if let eventName {
            lock.lock()
            defer { lock.unlock() }
            switch eventName {
            case "paywall_shown":
                paywallSessionID = UUID().uuidString.lowercased()
                purchaseAttemptID = nil
                paywallCompletedSuccessfully = false
                paywallContext = normalized.filter {
                    ["paywall_id", "variant", "placement", "trigger", "source"].contains($0.key)
                }
            case "purchase_started":
                if paywallSessionID == nil { paywallSessionID = UUID().uuidString.lowercased() }
                purchaseAttemptID = UUID().uuidString.lowercased()
            case "purchase_succeeded", "restore_purchases_succeeded":
                paywallCompletedSuccessfully = true
            case "paywall_dismissed" where paywallCompletedSuccessfully:
                paywallSessionID = nil
                purchaseAttemptID = nil
                paywallContext = [:]
                paywallCompletedSuccessfully = false
                return nil
            default:
                break
            }
            for (key, value) in paywallContext {
                normalized[key] = value
            }
            if let paywallSessionID { normalized["paywall_session_id"] = paywallSessionID }
            if let purchaseAttemptID { normalized["purchase_attempt_id"] = purchaseAttemptID }
            if ["paywall_dismissed", "purchase_succeeded", "purchase_cancelled", "purchase_failed"].contains(eventName) {
                if eventName != "purchase_succeeded" || purchaseAttemptID != nil {
                    purchaseAttemptID = nil
                }
            }
            if eventName == "paywall_dismissed" {
                paywallSessionID = nil
                paywallContext = [:]
                paywallCompletedSuccessfully = false
            }
        }
        return normalized.reduce(into: [String: Any]()) { result, item in
            guard JSONSerialization.isValidJSONObject([item.key: item.value]) else { return }
            result[item.key] = item.value
        }
    }
}
