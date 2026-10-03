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
    private static var analyticsDisabled = false

    /// Records one explicit first-launch event per app installation.
    /// Debug, Simulator, and SwiftUI Preview sessions are intentionally not sent.
    public static func trackFirstLaunch() {
        guard !analyticsDisabled else { return }
        let key = "bioscan.analytics.first_launch_recorded.\(Bundle.main.bundleIdentifier ?? "unknown")"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        track("first_launch")
    }

    public static func configure(_ configuration: AnalyticsConfiguration) {
        guard !configuration.projectToken.isEmpty, !configuration.host.isEmpty, !configuration.appID.isEmpty else {
            return
        }

        lock.lock()
        defer { lock.unlock() }
        guard !configured else { return }

        let processInfo = ProcessInfo.processInfo
        let isPreview = processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let isAutomatedTest = processInfo.environment["XCTestConfigurationFilePath"] != nil
            || processInfo.environment["XCTestBundlePath"] != nil
            || processInfo.arguments.contains("-ui-testing")
            || processInfo.arguments.contains("-unit-testing")
        #if targetEnvironment(simulator)
        let hasSandboxReceipt = false
        #else
        let hasSandboxReceipt = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif
        analyticsDisabled = configuration.debug || isSimulator || isPreview || isAutomatedTest

        let config = PostHogConfig(projectToken: configuration.projectToken, host: configuration.host)
        config.debug = configuration.debug
        config.captureApplicationLifecycleEvents = !analyticsDisabled
        config.captureScreenViews = !analyticsDisabled && configuration.capturesAutomaticScreenViews
        config.captureElementInteractions = false
        let sessionReplayEnabled = configuration.sessionReplayEnabled && !analyticsDisabled
        config.sessionReplay = sessionReplayEnabled
        if sessionReplayEnabled {
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
            "environment": isPreview ? "preview" : (isSimulator ? "simulator" : (isAutomatedTest ? "test" : (hasSandboxReceipt ? "testflight" : configuration.environment))),
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
        guard !eventName.isEmpty, !analyticsDisabled else { return }
        let canonicalName = canonicalEventName(eventName)
        var normalizedProperties = properties
        let isPaywallFunnelEvent = canonicalName.hasPrefix("paywall_")
            || canonicalName == "product_selected"
            || canonicalName.hasPrefix("purchase_")
            || canonicalName.hasPrefix("restore_")
        if isPaywallFunnelEvent {
            if normalizedProperties["product_id"] == nil, let product = normalizedProperties["product"] {
                normalizedProperties["product_id"] = product
            }
            if normalizedProperties["paywall_source"] == nil, let source = normalizedProperties["source"] as? String {
                normalizedProperties["paywall_source"] = normalizedPaywallSource(source)
            } else if let source = normalizedProperties["paywall_source"] as? String {
                normalizedProperties["paywall_source"] = normalizedPaywallSource(source)
            }
        }
        if canonicalName == "recognition_started" || canonicalName == "recognition_succeeded"
            || canonicalName == "recognition_failed" || canonicalName == "recognition_blocked" {
            if normalizedProperties["feature"] == nil {
                normalizedProperties["feature"] = normalizedProperties["entity_type"]
                    ?? normalizedProperties["recognition_mode"] ?? "identification"
            }
        }
        guard let properties = sanitize(normalizedProperties, eventName: canonicalName) else { return }
        PostHogSDK.shared.capture(canonicalName, properties: properties)
        if canonicalName == "recognition_started" || canonicalName == "sound_identify_start" {
            PostHogSDK.shared.capture("core_action_started", properties: properties)
        } else if canonicalName == "recognition_succeeded" || canonicalName == "sound_identify_success" {
            PostHogSDK.shared.capture("core_action_completed", properties: properties)
        } else if canonicalName == "recognition_blocked",
                  ((properties["reason"] as? String == "no_credits")
                    || (properties["error_type"] as? String == "quota")
                    || (properties["error_type"] as? String == "no_credits")) {
            PostHogSDK.shared.capture("quota_exhausted", properties: properties)
        }
    }

    private static func canonicalEventName(_ name: String) -> String {
        switch name {
        case "paywall_show", "paywall_shown": "paywall_viewed"
        case "paywall_product_selected", "paywall_product_select": "product_selected"
        case "purchase_succeeded", "purchase_success": "purchase_success"
        case "restore_purchases_started": "restore_started"
        case "restore_succeeded", "restore_purchases_succeeded", "restore_success": "restore_success"
        case "restore_purchases_failed": "restore_failed"
        case "restore_purchases_nothing_found": "restore_nothing_found"
        default: name
        }
    }

    private static func normalizedPaywallSource(_ source: String?) -> String {
        guard let source else { return "other" }
        return switch source {
        case "scanner", "recognition_gate", "recognition_quota", "home_import_quota", "home_quota_label", "home_quota_alert", "no_credits", "quota": "quota_exhausted"
        case "post_onboarding", "onboarding_complete": "onboarding"
        case "profile", "membership", "upgrade": "premium_feature"
        case "home_cta", "home_remaining_scans": "home"
        case "guide_demo_result": "result"
        case "purchase_page", "guide_demo": "premium_feature"
        case "onboarding", "home", "result", "settings", "quota_exhausted", "premium_feature", "history", "favorites", "other": source
        default: "other"
        }
    }

    public static func screen(_ name: String, properties: [String: Any] = [:]) {
        guard !name.isEmpty, !analyticsDisabled else { return }
        PostHogSDK.shared.screen(name, properties: sanitize(properties) ?? [:])
    }

    public static func identify(userID: String, properties: [String: Any] = [:]) {
        guard !userID.isEmpty, !analyticsDisabled else { return }
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
            case "paywall_viewed":
                paywallSessionID = UUID().uuidString.lowercased()
                purchaseAttemptID = nil
                paywallCompletedSuccessfully = false
                paywallContext = normalized.filter {
                    ["paywall_id", "variant", "placement", "trigger", "source", "paywall_source"].contains($0.key)
                }
            case "purchase_started":
                if paywallSessionID == nil { paywallSessionID = UUID().uuidString.lowercased() }
                purchaseAttemptID = UUID().uuidString.lowercased()
            case "purchase_success":
                paywallCompletedSuccessfully = true
            default:
                break
            }
            if eventName == "purchase_success", purchaseAttemptID == nil {
                return nil
            }
            let isPaywallEvent = (eventName.hasPrefix("paywall_") && eventName != "paywall_requested")
                || eventName.hasPrefix("purchase_")
                || eventName.hasPrefix("restore_")
            if isPaywallEvent {
                for (key, value) in paywallContext where normalized[key] == nil {
                    normalized[key] = value
                }
                if let source = normalized["source"] as? String {
                    normalized["paywall_source"] = normalizedPaywallSource(source)
                } else if normalized["paywall_source"] == nil {
                    normalized["paywall_source"] = "other"
                }
                if let paywallSessionID { normalized["paywall_session_id"] = paywallSessionID }
                if let purchaseAttemptID { normalized["purchase_attempt_id"] = purchaseAttemptID }
                if eventName == "paywall_dismissed" {
                    normalized["did_convert"] = paywallCompletedSuccessfully
                }
            }
            if ["paywall_dismissed", "purchase_success", "purchase_cancelled", "purchase_failed"].contains(eventName) {
                if eventName != "purchase_success" || purchaseAttemptID != nil {
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
