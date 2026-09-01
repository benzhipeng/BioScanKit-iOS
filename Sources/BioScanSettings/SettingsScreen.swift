import BioScanDesign
import SwiftUI

public struct SettingsScreen<Membership: View, Extra: View>: View {
    @Environment(\.openURL) private var openURL

    @Binding private var appearanceID: String
    @State private var restoreAlert: RestoreAlert?
    @State private var isRestoring = false

    private let configuration: SettingsConfiguration
    private let actions: SettingsActions
    private let recommendationsBundle: Bundle
    private let membership: Membership
    private let extra: (SettingsPageMetrics) -> Extra

    public init(
        configuration: SettingsConfiguration,
        appearanceID: Binding<String>,
        actions: SettingsActions = SettingsActions(),
        recommendationsBundle: Bundle = .main,
        @ViewBuilder membership: () -> Membership,
        @ViewBuilder extra: @escaping () -> Extra
    ) {
        self.configuration = configuration
        _appearanceID = appearanceID
        self.actions = actions
        self.recommendationsBundle = recommendationsBundle
        self.membership = membership()
        self.extra = { _ in extra() }
    }

    public init(
        configuration: SettingsConfiguration,
        appearanceID: Binding<String>,
        actions: SettingsActions = SettingsActions(),
        recommendationsBundle: Bundle = .main,
        @ViewBuilder membership: () -> Membership,
        @ViewBuilder extra: @escaping (SettingsPageMetrics) -> Extra
    ) {
        self.configuration = configuration
        _appearanceID = appearanceID
        self.actions = actions
        self.recommendationsBundle = recommendationsBundle
        self.membership = membership()
        self.extra = extra
    }

    public var body: some View {
        SettingsPageView(
            title: configuration.copy.title,
            versionText: "\(configuration.appName) · \(AppVersion().displayText)",
            versionTapped: actions.versionTapped
        ) { metrics in
            VStack(alignment: .leading, spacing: 16) {
                membership

                if configuration.showsAppearance
                    || configuration.showsLanguage
                    || configuration.showsSystemSettings {
                    generalSection
                }

                extra(metrics)

                if configuration.showsSupportSection {
                    supportSection
                }

                if shouldShowRateApp {
                    rateAppCard
                }

                if configuration.showsRecommendedApps, !recommendations.isEmpty {
                    recommendedAppsSection
                }
            }
        }
        .overlay {
            if isRestoring {
                ProgressView()
                    .padding(18)
                    .background(.regularMaterial, in: .rect(cornerRadius: 14))
                    .accessibilityLabel("Restoring purchases")
            }
        }
        .alert(item: $restoreAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            actions.track(.shown)
        }
    }

    private var generalSection: some View {
        SettingsSectionView(
            configuration.copy.generalSectionTitle,
            theme: configuration.theme
        ) {
            if configuration.showsAppearance {
                appearancePicker
            }

            if configuration.showsAppearance && configuration.showsLanguage {
                SettingsDivider()
            }

            if configuration.showsLanguage {
                SettingsRowView(
                    icon: "globe",
                    title: configuration.copy.languageTitle,
                    theme: configuration.theme
                ) {
                    actions.track(.languageTapped)
                    actions.openLanguageSettings?()
                }
            }

            if configuration.showsSystemSettings {
                if configuration.showsAppearance || configuration.showsLanguage {
                    SettingsDivider()
                }

                SettingsRowView(
                    icon: "gearshape.fill",
                    title: configuration.copy.systemSettingsTitle,
                    subtitle: configuration.copy.systemSettingsSubtitle,
                    isExternal: true,
                    theme: configuration.theme
                ) {
                    actions.openSystemSettings?()
                }
            }
        }
    }

    private var appearancePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(configuration.copy.appearanceTitle)
                .font(.system(size: 14, weight: .bold, design: .rounded))

            Picker(configuration.copy.appearanceTitle, selection: $appearanceID) {
                ForEach(configuration.appearanceOptions) { option in
                    Text(option.title)
                        .tag(option.id)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: appearanceID) { value in
                actions.track(.appearanceChanged(value))
            }
        }
    }

    private var supportSection: some View {
        SettingsSectionView(
            configuration.copy.supportSectionTitle,
            theme: configuration.theme
        ) {
            if configuration.privacyPolicyURL != nil || actions.openPrivacyPolicy != nil {
                supportRow(
                    icon: "hand.raised.fill",
                    title: configuration.copy.privacyPolicyTitle,
                    subtitle: configuration.copy.privacyPolicySubtitle,
                    event: .privacyPolicyTapped,
                    action: {
                        if let openPrivacyPolicy = actions.openPrivacyPolicy {
                            openPrivacyPolicy()
                        } else if let url = configuration.privacyPolicyURL {
                            openURL(url)
                        }
                    }
                )
                if hasSupportRow(after: .privacy) {
                    SettingsDivider()
                }
            }

            if configuration.termsOfUseURL != nil || actions.openTermsOfUse != nil {
                supportRow(
                    icon: "doc.text.fill",
                    title: configuration.copy.termsOfUseTitle,
                    subtitle: configuration.copy.termsOfUseSubtitle,
                    event: .termsOfUseTapped,
                    action: {
                        if let openTermsOfUse = actions.openTermsOfUse {
                            openTermsOfUse()
                        } else if let url = configuration.termsOfUseURL {
                            openURL(url)
                        }
                    }
                )
                if hasSupportRow(after: .terms) {
                    SettingsDivider()
                }
            }

            if configuration.feedbackEmail != nil || actions.sendFeedback != nil {
                supportRow(
                    icon: "envelope.fill",
                    title: configuration.copy.feedbackTitle,
                    subtitle: configuration.copy.feedbackSubtitle,
                    event: .feedbackTapped,
                    action: {
                        if let sendFeedback = actions.sendFeedback {
                            sendFeedback()
                        } else if let email = configuration.feedbackEmail {
                            openURL(feedbackURL(email: email))
                        }
                    }
                )
                if hasSupportRow(after: .feedback) {
                    SettingsDivider()
                }
            }

            if configuration.showsRestorePurchase, actions.restorePurchases != nil {
                SettingsRowView(
                    icon: "arrow.clockwise",
                    title: configuration.copy.restorePurchaseTitle,
                    subtitle: isRestoring
                        ? "Checking the App Store…"
                        : configuration.copy.restorePurchaseSubtitle,
                    isExternal: true,
                    theme: configuration.theme
                ) {
                    restore()
                }
                .disabled(isRestoring)
            }
        }
    }

    private var rateAppCard: some View {
        SettingsCardView {
            SettingsRowView(
                icon: "star.fill",
                title: configuration.copy.rateAppTitle,
                subtitle: configuration.copy.rateAppSubtitle,
                isExternal: true,
                theme: configuration.theme
            ) {
                actions.track(.rateAppTapped)
                if let rateApp = actions.rateApp {
                    rateApp()
                } else if let appStoreURL {
                    openURL(appStoreURL)
                }
            }
        }
    }

    private var recommendedAppsSection: some View {
        SettingsSectionView(
            configuration.copy.recommendedAppsTitle,
            theme: configuration.theme
        ) {
            ForEach(Array(recommendations.enumerated()), id: \.element.id) { index, app in
                Button {
                    actions.track(.recommendedAppTapped(app.id))
                    if let openRecommendedApp = actions.openRecommendedApp {
                        openRecommendedApp(app)
                    } else {
                        openURL(app.appStoreURL)
                    }
                } label: {
                    SettingsRecommendedAppCardView(
                        app: app,
                        theme: configuration.theme,
                        bundle: recommendationsBundle
                    )
                }
                .buttonStyle(.plain)

                if index < recommendations.count - 1 {
                    SettingsDivider()
                }
            }
        }
    }

    private var recommendations: [RecommendedApp] {
        RecommendedAppsLoader.load(
            resourceName: configuration.recommendedAppsResourceName,
            bundle: recommendationsBundle,
            excluding: configuration.currentAppID
        )
    }

    private var appStoreURL: URL? {
        guard let id = configuration.appStoreID else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)?action=write-review")
    }

    private var shouldShowRateApp: Bool {
        configuration.showsRateApp && (actions.rateApp != nil || appStoreURL != nil)
    }

    private func supportRow(
        icon: String,
        title: String,
        subtitle: String,
        event: SettingsEvent,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        SettingsRowView(
            icon: icon,
            title: title,
            subtitle: subtitle,
            isExternal: true,
            theme: configuration.theme
        ) {
            actions.track(event)
            action()
        }
    }

    private enum SupportRow {
        case privacy
        case terms
        case feedback
    }

    private func hasSupportRow(after row: SupportRow) -> Bool {
        let hasTerms = configuration.termsOfUseURL != nil || actions.openTermsOfUse != nil
        let hasFeedback = configuration.feedbackEmail != nil || actions.sendFeedback != nil
        let hasRestore = configuration.showsRestorePurchase && actions.restorePurchases != nil

        switch row {
        case .privacy:
            return hasTerms || hasFeedback || hasRestore
        case .terms:
            return hasFeedback || hasRestore
        case .feedback:
            return hasRestore
        }
    }

    private func feedbackURL(email: String) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: "\(configuration.appName) Feedback"),
            URLQueryItem(
                name: "body",
                value: "\n\nApp version: \(AppVersion().displayText)"
            )
        ]
        return components.url ?? URL(string: "mailto:\(email)")!
    }

    private func restore() {
        guard let restorePurchases = actions.restorePurchases else { return }
        actions.track(.restoreTapped)
        isRestoring = true

        Task {
            defer { isRestoring = false }
            do {
                let result = try await restorePurchases()
                actions.track(.restoreFinished(result))
                switch result {
                case .restored:
                    restoreAlert = RestoreAlert(
                        title: "Purchase Restored",
                        message: "Your purchase has been restored."
                    )
                case .nothingToRestore:
                    restoreAlert = RestoreAlert(
                        title: "No Purchase Found",
                        message: "No restorable purchase was found for this Apple ID."
                    )
                }
            } catch {
                actions.track(.restoreFailed)
                restoreAlert = RestoreAlert(
                    title: "Restore Failed",
                    message: error.localizedDescription
                )
            }
        }
    }
}

private struct RestoreAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
