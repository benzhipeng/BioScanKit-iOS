import SwiftUI

public struct BioScanTheme: Sendable {
    public let accent: Color
    public let success: Color
    public let warning: Color
    public let pageBackground: AdaptiveColor
    public let cardBackground: AdaptiveColor
    public let elevatedCardBackground: AdaptiveColor
    public let primaryText: AdaptiveColor
    public let secondaryText: AdaptiveColor
    public let border: AdaptiveColor
    public let cardCornerRadius: CGFloat
    public let buttonCornerRadius: CGFloat
    public let horizontalPadding: CGFloat
    public let sectionSpacing: CGFloat
    public let fontDesign: Font.Design

    public init(
        accent: Color,
        success: Color,
        warning: Color,
        pageBackground: AdaptiveColor,
        cardBackground: AdaptiveColor,
        elevatedCardBackground: AdaptiveColor,
        primaryText: AdaptiveColor,
        secondaryText: AdaptiveColor,
        border: AdaptiveColor,
        cardCornerRadius: CGFloat = 18,
        buttonCornerRadius: CGFloat = 14,
        horizontalPadding: CGFloat = 18,
        sectionSpacing: CGFloat = 20,
        fontDesign: Font.Design = .rounded
    ) {
        self.accent = accent
        self.success = success
        self.warning = warning
        self.pageBackground = pageBackground
        self.cardBackground = cardBackground
        self.elevatedCardBackground = elevatedCardBackground
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.border = border
        self.cardCornerRadius = cardCornerRadius
        self.buttonCornerRadius = buttonCornerRadius
        self.horizontalPadding = horizontalPadding
        self.sectionSpacing = sectionSpacing
        self.fontDesign = fontDesign
    }
}

public extension BioScanTheme {
    static let iNature = BioScanTheme(
        accent: Color(red: 0.14, green: 0.52, blue: 0.20),
        success: Color(red: 0.16, green: 0.62, blue: 0.33),
        warning: Color(red: 0.93, green: 0.58, blue: 0.12),
        pageBackground: AdaptiveColor(
            light: Color(red: 0.95, green: 0.96, blue: 0.95),
            dark: Color(red: 0.08, green: 0.10, blue: 0.12)
        ),
        cardBackground: AdaptiveColor(
            light: .white,
            dark: Color(red: 0.13, green: 0.15, blue: 0.18)
        ),
        elevatedCardBackground: AdaptiveColor(
            light: Color(red: 0.89, green: 0.93, blue: 0.89),
            dark: Color(red: 0.15, green: 0.19, blue: 0.16)
        ),
        primaryText: AdaptiveColor(
            light: Color(red: 0.08, green: 0.12, blue: 0.20),
            dark: Color(red: 0.93, green: 0.95, blue: 0.98)
        ),
        secondaryText: AdaptiveColor(
            light: Color(red: 0.52, green: 0.58, blue: 0.66),
            dark: Color(red: 0.62, green: 0.68, blue: 0.76)
        ),
        border: AdaptiveColor(
            light: Color(red: 0.84, green: 0.88, blue: 0.91),
            dark: Color.white.opacity(0.14)
        )
    )
}
