import BioScanDesign
import Foundation
import SwiftUI

public struct SettingsCopy: Sendable {
    public let title: String
    public let generalSectionTitle: String
    public let supportSectionTitle: String
    public let recommendedAppsTitle: String
    public let appearanceTitle: String
    public let languageTitle: String
    public let systemSettingsTitle: String
    public let systemSettingsSubtitle: String
    public let privacyPolicyTitle: String
    public let privacyPolicySubtitle: String
    public let termsOfUseTitle: String
    public let termsOfUseSubtitle: String
    public let feedbackTitle: String
    public let feedbackSubtitle: String
    public let restorePurchaseTitle: String
    public let restorePurchaseSubtitle: String
    public let rateAppTitle: String
    public let rateAppSubtitle: String
    public let versionTitle: String

    public init(
        title: String = "Settings",
        generalSectionTitle: String = "General",
        supportSectionTitle: String = "Support & Legal",
        recommendedAppsTitle: String = "Recommended Apps",
        appearanceTitle: String = "Appearance",
        languageTitle: String = "Language",
        systemSettingsTitle: String = "System Permissions",
        systemSettingsSubtitle: String = "Open iOS Settings for camera and photos",
        privacyPolicyTitle: String = "Privacy Policy",
        privacyPolicySubtitle: String = "How we collect and use data",
        termsOfUseTitle: String = "Terms of Use",
        termsOfUseSubtitle: String = "Terms of use and responsibilities",
        feedbackTitle: String = "Contact & Feedback",
        feedbackSubtitle: String = "Help us improve the app",
        restorePurchaseTitle: String = "Restore Purchase",
        restorePurchaseSubtitle: String = "Recover access on this device",
        rateAppTitle: String = "Rate on the App Store",
        rateAppSubtitle: String = "Leave a rating on the App Store",
        versionTitle: String = "Version"
    ) {
        self.title = title
        self.generalSectionTitle = generalSectionTitle
        self.supportSectionTitle = supportSectionTitle
        self.recommendedAppsTitle = recommendedAppsTitle
        self.appearanceTitle = appearanceTitle
        self.languageTitle = languageTitle
        self.systemSettingsTitle = systemSettingsTitle
        self.systemSettingsSubtitle = systemSettingsSubtitle
        self.privacyPolicyTitle = privacyPolicyTitle
        self.privacyPolicySubtitle = privacyPolicySubtitle
        self.termsOfUseTitle = termsOfUseTitle
        self.termsOfUseSubtitle = termsOfUseSubtitle
        self.feedbackTitle = feedbackTitle
        self.feedbackSubtitle = feedbackSubtitle
        self.restorePurchaseTitle = restorePurchaseTitle
        self.restorePurchaseSubtitle = restorePurchaseSubtitle
        self.rateAppTitle = rateAppTitle
        self.rateAppSubtitle = rateAppSubtitle
        self.versionTitle = versionTitle
    }

    public static let iNature = SettingsCopy()

    public static func standard(
        appName: String,
        title: String = "Settings"
    ) -> SettingsCopy {
        SettingsCopy(
            title: title,
            generalSectionTitle: "GENERAL",
            supportSectionTitle: "LEGAL & SUPPORT",
            recommendedAppsTitle: "OTHER APPS",
            appearanceTitle: "Appearance",
            systemSettingsTitle: "System Permissions",
            systemSettingsSubtitle: "Open iOS Settings for camera and photos",
            privacyPolicyTitle: "Privacy Policy",
            privacyPolicySubtitle: "How we collect and use data",
            termsOfUseTitle: "User Agreement",
            termsOfUseSubtitle: "Terms of use and responsibilities",
            feedbackTitle: "Contact & Feedback",
            feedbackSubtitle: "Help us improve \(appName)",
            restorePurchaseTitle: "Restore Purchase",
            restorePurchaseSubtitle: "Recover access on this device",
            rateAppTitle: "Rate \(appName)",
            rateAppSubtitle: "Leave a rating on the App Store"
        )
    }
}

public struct SettingsAppearanceOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String

    public init(id: String, title: String, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }

    public static let standard: [SettingsAppearanceOption] = [
        SettingsAppearanceOption(id: "system", title: "System", systemImage: "circle.lefthalf.filled"),
        SettingsAppearanceOption(id: "light", title: "Light", systemImage: "sun.max.fill"),
        SettingsAppearanceOption(id: "dark", title: "Dark", systemImage: "moon.fill")
    ]
}

public struct SettingsConfiguration: Sendable {
    public let appName: String
    public let currentAppID: String
    public let theme: BioScanTheme
    public let copy: SettingsCopy
    public let privacyPolicyURL: URL?
    public let termsOfUseURL: URL?
    public let feedbackEmail: String?
    public let appStoreID: String?
    public let appearanceOptions: [SettingsAppearanceOption]
    public let showsAppearance: Bool
    public let showsLanguage: Bool
    public let showsSystemSettings: Bool
    public let showsSupportSection: Bool
    public let showsRestorePurchase: Bool
    public let showsRateApp: Bool
    public let showsRecommendedApps: Bool
    public let recommendedAppsResourceName: String

    public init(
        appName: String,
        currentAppID: String,
        theme: BioScanTheme = .iNature,
        copy: SettingsCopy = .iNature,
        privacyPolicyURL: URL? = nil,
        termsOfUseURL: URL? = nil,
        feedbackEmail: String? = nil,
        appStoreID: String? = nil,
        appearanceOptions: [SettingsAppearanceOption] = SettingsAppearanceOption.standard,
        showsAppearance: Bool = true,
        showsLanguage: Bool = false,
        showsSystemSettings: Bool = false,
        showsSupportSection: Bool = true,
        showsRestorePurchase: Bool = true,
        showsRateApp: Bool = true,
        showsRecommendedApps: Bool = true,
        recommendedAppsResourceName: String = "RecommendedApps"
    ) {
        self.appName = appName
        self.currentAppID = currentAppID
        self.theme = theme
        self.copy = copy
        self.privacyPolicyURL = privacyPolicyURL
        self.termsOfUseURL = termsOfUseURL
        self.feedbackEmail = feedbackEmail
        self.appStoreID = appStoreID
        self.appearanceOptions = appearanceOptions
        self.showsAppearance = showsAppearance
        self.showsLanguage = showsLanguage
        self.showsSystemSettings = showsSystemSettings
        self.showsSupportSection = showsSupportSection
        self.showsRestorePurchase = showsRestorePurchase
        self.showsRateApp = showsRateApp
        self.showsRecommendedApps = showsRecommendedApps
        self.recommendedAppsResourceName = recommendedAppsResourceName
    }
}

public enum RestoreResult: Equatable, Sendable {
    case restored
    case nothingToRestore
}

public enum SettingsEvent: Equatable, Sendable {
    case shown
    case appearanceChanged(String)
    case languageTapped
    case privacyPolicyTapped
    case termsOfUseTapped
    case feedbackTapped
    case restoreTapped
    case restoreFinished(RestoreResult)
    case restoreFailed
    case rateAppTapped
    case recommendedAppTapped(String)
}

public struct SettingsActions {
    public let restorePurchases: (@MainActor () async throws -> RestoreResult)?
    public let openSystemSettings: (@MainActor () -> Void)?
    public let openLanguageSettings: (@MainActor () -> Void)?
    public let openPrivacyPolicy: (@MainActor () -> Void)?
    public let openTermsOfUse: (@MainActor () -> Void)?
    public let sendFeedback: (@MainActor () -> Void)?
    public let rateApp: (@MainActor () -> Void)?
    public let openRecommendedApp: (@MainActor (RecommendedApp) -> Void)?
    public let versionTapped: (@MainActor () -> Void)?
    public let track: @MainActor (SettingsEvent) -> Void

    public init(
        restorePurchases: (@MainActor () async throws -> RestoreResult)? = nil,
        openSystemSettings: (@MainActor () -> Void)? = nil,
        openLanguageSettings: (@MainActor () -> Void)? = nil,
        openPrivacyPolicy: (@MainActor () -> Void)? = nil,
        openTermsOfUse: (@MainActor () -> Void)? = nil,
        sendFeedback: (@MainActor () -> Void)? = nil,
        rateApp: (@MainActor () -> Void)? = nil,
        openRecommendedApp: (@MainActor (RecommendedApp) -> Void)? = nil,
        versionTapped: (@MainActor () -> Void)? = nil,
        track: @escaping @MainActor (SettingsEvent) -> Void = { _ in }
    ) {
        self.restorePurchases = restorePurchases
        self.openSystemSettings = openSystemSettings
        self.openLanguageSettings = openLanguageSettings
        self.openPrivacyPolicy = openPrivacyPolicy
        self.openTermsOfUse = openTermsOfUse
        self.sendFeedback = sendFeedback
        self.rateApp = rateApp
        self.openRecommendedApp = openRecommendedApp
        self.versionTapped = versionTapped
        self.track = track
    }
}
