import BioScanDesign
import SwiftUI
import UIKit

public struct SettingsSectionView<Content: View>: View {
    private let title: String
    private let theme: BioScanTheme
    private let content: Content

    public init(
        _ title: String,
        theme: BioScanTheme,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.theme = theme
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSectionTitleView(title)
            SettingsCardView {
                content
            }
        }
    }
}

public struct SettingsSectionTitleView: View {
    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

public struct SettingsCardView<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 12) {
            content
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        }
    }
}

public struct SettingsRowView: View {
    private let icon: String
    private let title: String
    private let subtitle: String?
    private let detail: String?
    private let isExternal: Bool
    private let theme: BioScanTheme
    private let usesThemeTextColors: Bool
    private let action: () -> Void

    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        detail: String? = nil,
        isExternal: Bool = false,
        usesThemeTextColors: Bool = false,
        theme: BioScanTheme,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.isExternal = isExternal
        self.usesThemeTextColors = usesThemeTextColors
        self.theme = theme
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            SettingsRowLabelView(
                icon: icon,
                title: title,
                subtitle: subtitle,
                detail: detail,
                isExternal: isExternal,
                usesThemeTextColors: usesThemeTextColors,
                theme: theme
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint(isExternal ? "Opens an external destination" : "")
    }
}

public struct SettingsRowLabelView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let icon: String
    private let title: String
    private let subtitle: String?
    private let detail: String?
    private let isExternal: Bool
    private let theme: BioScanTheme
    private let usesThemeTextColors: Bool

    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        detail: String? = nil,
        isExternal: Bool = false,
        usesThemeTextColors: Bool = false,
        theme: BioScanTheme = .iNature
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.isExternal = isExternal
        self.usesThemeTextColors = usesThemeTextColors
        self.theme = theme
    }

    public var body: some View {
        HStack(alignment: subtitle == nil ? .center : .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.accent)
                .frame(width: 44, height: 44)
                .background(
                    Color(uiColor: .systemBackground),
                    in: .rect(cornerRadius: 12)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        usesThemeTextColors
                            ? theme.primaryText.resolve(for: colorScheme)
                            : Color.primary
                    )

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            usesThemeTextColors
                                ? theme.secondaryText.resolve(for: colorScheme)
                                : Color.secondary
                        )
                }
            }

            Spacer()

            if let detail {
                Text(detail)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        usesThemeTextColors
                            ? theme.secondaryText.resolve(for: colorScheme)
                            : Color.secondary
                    )
            }

            Image(systemName: isExternal ? "arrow.up.right" : "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(
                    usesThemeTextColors
                        ? theme.secondaryText.resolve(for: colorScheme)
                        : Color.secondary
                )
                .padding(.top, subtitle == nil ? 2 : 6)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 8)
        .contentShape(.rect)
    }
}

public struct SettingsNavigationRowView: View {
    private let icon: String
    private let title: String
    private let subtitle: String?
    private let detail: String?
    private let theme: BioScanTheme

    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        detail: String? = nil,
        theme: BioScanTheme = .iNature
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.theme = theme
    }

    public var body: some View {
        SettingsRowLabelView(
            icon: icon,
            title: title,
            subtitle: subtitle,
            detail: detail,
            theme: theme
        )
    }
}

public struct SettingsActionRowView: View {
    private let icon: String
    private let title: String
    private let subtitle: String?
    private let detail: String?
    private let theme: BioScanTheme

    public init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        detail: String? = nil,
        theme: BioScanTheme = .iNature
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.theme = theme
    }

    public var body: some View {
        SettingsRowLabelView(
            icon: icon,
            title: title,
            subtitle: subtitle,
            detail: detail,
            isExternal: true,
            theme: theme
        )
    }
}

public struct SettingsDivider: View {
    public init() {}

    public var body: some View {
        Divider()
            .opacity(0.18)
    }
}

public enum SettingsMembershipState: Equatable, Sendable {
    case lifetime(title: String, subtitle: String)
    case upgrade(remainingText: String?, actionTitle: String, footnote: String)
}

public struct SettingsMembershipCardView: View {
    private let state: SettingsMembershipState
    private let theme: BioScanTheme
    private let isActionDisabled: Bool
    private let action: (() -> Void)?

    public init(
        state: SettingsMembershipState,
        theme: BioScanTheme,
        isActionDisabled: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.state = state
        self.theme = theme
        self.isActionDisabled = isActionDisabled
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch state {
            case let .lifetime(title, subtitle):
                lifetimeContent(title: title, subtitle: subtitle)
            case let .upgrade(remainingText, actionTitle, footnote):
                upgradeContent(
                    remainingText: remainingText,
                    actionTitle: actionTitle,
                    footnote: footnote
                )
            }
        }
        .padding(12)
        .background(
            Color(uiColor: .secondarySystemBackground),
            in: .rect(cornerRadius: 14)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lifetimeContent(title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func upgradeContent(
        remainingText: String?,
        actionTitle: String,
        footnote: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let remainingText, !remainingText.isEmpty {
                Text(remainingText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }

            if let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isActionDisabled)
                .opacity(isActionDisabled ? 0.6 : 1)
            }

            Text(footnote)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct SettingsRecommendedAppCardView: View {
    let app: RecommendedApp
    let theme: BioScanTheme
    let bundle: Bundle

    public init(
        app: RecommendedApp,
        theme: BioScanTheme,
        bundle: Bundle = .main
    ) {
        self.app = app
        self.theme = theme
        self.bundle = bundle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.94))
                        .shadow(
                            color: primaryAccent.opacity(0.30),
                            radius: 14,
                            x: 0,
                            y: 10
                        )
                    appIcon
                }
                .frame(width: 78, height: 78)

                VStack(alignment: .leading, spacing: 5) {
                    Text("RECOMMENDED")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(Color.white.opacity(0.68))

                    Text(app.name)
                        .font(.system(size: 31, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(primaryAccent)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.92), in: Circle())
                    .accessibilityHidden(true)
            }

            Text(app.subtitle)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.84))
                .lineSpacing(4)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: accentColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay(alignment: .bottomTrailing) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 180, height: 34)
                .rotationEffect(.degrees(-18))
                .offset(x: 26, y: -8)
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        }
        .shadow(color: primaryAccent.opacity(0.22), radius: 18, x: 0, y: 12)
        .contentShape(.rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.name), \(app.subtitle)")
        .accessibilityHint("Opens in the App Store")
    }

    private var accentColors: [Color] {
        let colors = app.backgroundHexes.compactMap(Color.init(settingsHex:))
        if !colors.isEmpty {
            return colors
        }
        return [
            theme.accent.opacity(0.92),
            theme.accent.opacity(0.72),
            theme.accent
        ]
    }

    private var primaryAccent: Color {
        accentColors.first ?? theme.accent
    }

    @ViewBuilder
    private var appIcon: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 74, height: 74)
                .clipShape(.rect(cornerRadius: 18))
                .accessibilityHidden(true)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.gray.opacity(0.72))
                .frame(width: 74, height: 74)
                .accessibilityHidden(true)
        }
    }

    private var image: UIImage? {
        guard let imageName = app.imageName else { return nil }
        if let image = UIImage(named: imageName, in: bundle, compatibleWith: nil) {
            return image
        }
        guard let url = bundle.url(forResource: imageName, withExtension: "png") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}

private extension Color {
    init?(settingsHex value: String) {
        let cleaned = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard let raw = UInt64(cleaned, radix: 16) else { return nil }

        let red: Double
        let green: Double
        let blue: Double
        switch cleaned.count {
        case 3:
            red = Double((raw >> 8) * 17) / 255
            green = Double((raw >> 4 & 0xF) * 17) / 255
            blue = Double((raw & 0xF) * 17) / 255
        case 6:
            red = Double(raw >> 16 & 0xFF) / 255
            green = Double(raw >> 8 & 0xFF) / 255
            blue = Double(raw & 0xFF) / 255
        default:
            return nil
        }
        self.init(red: red, green: green, blue: blue)
    }
}
