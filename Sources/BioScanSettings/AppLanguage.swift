import BioScanDesign
import SwiftUI

/// Shared app-language persistence and presentation used by settings screens.
public enum BioScanAppLanguage {
    public static let storageKey = "app_language"

    public static var availableIdentifiers: [String] {
        Bundle.main.localizations
            .filter { $0 != "Base" }
            .sorted()
    }

    public static var selectedIdentifier: String {
        let saved = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return availableIdentifiers.contains(saved) ? saved : ""
    }

    public static var systemIdentifier: String {
        Bundle.preferredLocalizations(
            from: availableIdentifiers,
            forPreferences: Locale.preferredLanguages
        ).first ?? availableIdentifiers.first ?? "en"
    }

    public static var locale: Locale { BioScanLocalization.shared.locale }

    public static func select(_ identifier: String) {
        let selected = availableIdentifiers.contains(identifier) ? identifier : ""
        UserDefaults.standard.set(selected, forKey: storageKey)
        BioScanLocalization.shared.languageIdentifier = selected
    }

    public static func restoreSelection() {
        select(selectedIdentifier)
    }

    public static func displayName(for identifier: String) -> String {
        // Keep the primary label in the language's own script instead of
        // letting the current device locale decide how it is displayed.
        let nativeNames: [String: String] = [
            "de": "Deutsch",
            "en": "English",
            "es": "Español",
            "fr": "Français",
            "it": "Italiano",
            "ja": "日本語",
            "nl": "Nederlands",
            "zh-CN": "简体中文",
            "zh-Hans": "简体中文"
        ]
        return nativeNames[identifier]
            ?? Locale(identifier: identifier).localizedString(forIdentifier: identifier)
            ?? identifier
    }
}

public struct AppLanguageView: View {
    @AppStorage(BioScanAppLanguage.storageKey) private var language = ""
    @Environment(\.locale) private var locale

    private let theme: BioScanTheme
    private let title: String
    private let availableLanguagesTitle: String
    private let informationText: String

    public init(
        theme: BioScanTheme = .iNature,
        title: String = "App Language",
        availableLanguagesTitle: String = "AVAILABLE LANGUAGES",
        informationText: String = "Changes apply immediately."
    ) {
        self.theme = theme
        self.title = title
        self.availableLanguagesTitle = availableLanguagesTitle
        self.informationText = informationText
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                SettingsCardView {
                    languageRow(
                        identifier: "",
                        title: BioScanLocalization.shared.string("Follow System"),
                        subtitle: locale.localizedString(forIdentifier: BioScanAppLanguage.systemIdentifier)
                    )
                }

                VStack(alignment: .leading, spacing: 16) {
                    SettingsSectionTitleView(availableLanguagesTitle)
                    SettingsCardView {
                        VStack(spacing: 0) {
                            ForEach(BioScanAppLanguage.availableIdentifiers, id: \.self) { identifier in
                                if identifier != BioScanAppLanguage.availableIdentifiers.first {
                                    Divider().padding(.leading, 56)
                                }
                                let nativeName = BioScanAppLanguage.displayName(for: identifier)
                                let translatedName = locale.localizedString(forIdentifier: identifier)
                                languageRow(
                                    identifier: identifier,
                                    title: nativeName,
                                    subtitle: translatedName == nativeName ? nil : translatedName
                                )
                            }
                        }
                    }
                }

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(theme.accent)
                        .accessibilityHidden(true)
                    Text(informationText)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 4)
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .background {
            LinearGradient(
                colors: [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .bioScanPushNavigation(title: title)
        .onAppear { BioScanAppLanguage.restoreSelection() }
    }

    @ViewBuilder
    private func languageRow(identifier: String, title: String, subtitle: String?) -> some View {
        let selected = BioScanAppLanguage.selectedIdentifier
        let isSelected = selected == identifier
        Button {
            // Update the SwiftUI-backed value before persisting through the
            // shared language service. Writing UserDefaults first can make
            // @AppStorage see the following assignment as unchanged, so
            // parent screens miss the refresh needed for localized resources.
            language = identifier
            BioScanAppLanguage.select(identifier)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: identifier.isEmpty ? "gearshape.fill" : "character.bubble")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? theme.accent.opacity(0.10) : Color(uiColor: .systemBackground), in: .rect(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    if let subtitle {
                        Text(verbatim: subtitle)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected ? theme.accent : Color.secondary.opacity(0.25))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("app-language-\(identifier.isEmpty ? "system" : identifier)")
    }
}
