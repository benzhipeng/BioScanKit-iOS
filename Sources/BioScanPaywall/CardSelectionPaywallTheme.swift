import BioScanDesign
import SwiftUI

public extension CardSelectionPaywallTheme {
    static func derived(from theme: BioScanTheme) -> CardSelectionPaywallTheme {
        CardSelectionPaywallTheme(
            backgroundGradient: [
                .fixed(theme.accent),
                theme.elevatedCardBackground,
                theme.pageBackground
            ],
            glowStrong: AdaptiveColor(
                light: Color.white.opacity(0.18),
                dark: Color.white.opacity(0.08)
            ),
            glowSoft: .fixed(theme.accent.opacity(0.12)),
            closeBackground: theme.cardBackground.applyingOpacity(0.86),
            closeIcon: theme.secondaryText,
            headerTitle: theme.primaryText,
            headerSubtitle: theme.secondaryText,
            counterBackground: .fixed(theme.accent.opacity(0.10)),
            counterBorder: .fixed(theme.accent.opacity(0.20)),
            counterText: .fixed(theme.accent),
            counterDot: .fixed(theme.accent),
            statusActive: .fixed(theme.success),
            mascotCard: theme.cardBackground,
            mascotCardStroke: theme.border,
            heroTextPrimary: .fixed(.white),
            heroTextSecondary: .fixed(Color.white.opacity(0.80)),
            heroGlass: .fixed(Color.white.opacity(0.14)),
            heroGlassStroke: .fixed(Color.white.opacity(0.24)),
            cardBackground: theme.cardBackground,
            cardBorder: theme.border,
            cardTitle: theme.primaryText,
            cardSubtitle: theme.secondaryText,
            selectedFill: theme.elevatedCardBackground,
            selectedBorder: .fixed(theme.accent),
            accentText: .fixed(theme.accent),
            lifetimeStart: .fixed(theme.accent),
            lifetimeMid: .fixed(theme.accent.opacity(0.86)),
            lifetimeEnd: .fixed(theme.accent.opacity(0.72)),
            lifetimeHighlight: .fixed(Color.white.opacity(0.88)),
            ctaGradient: [
                .fixed(theme.accent),
                .fixed(theme.accent.opacity(0.78))
            ],
            ctaStroke: .fixed(Color.white.opacity(0.14)),
            ctaShadow: .fixed(theme.accent),
            shadow: .fixed(theme.accent),
            restoreText: theme.secondaryText
        )
    }

    static let legacyRock = CardSelectionPaywallTheme(
        backgroundGradient: [
            .fixed(Color(paywallRGB: 0x139C8D)),
            .paywall(light: 0xBFE9E4, dark: 0x163B38),
            .paywall(light: 0xF5FBF9, dark: 0x081110),
            .paywall(light: 0xF5FBF9, dark: 0x081110)
        ],
        glowStrong: .paywall(
            light: 0xFFFFFF,
            dark: 0x49D7C5,
            lightAlpha: 0.18,
            darkAlpha: 0.10
        ),
        glowSoft: .paywall(
            light: 0x2DD4BF,
            dark: 0x19B3A3,
            lightAlpha: 0.12,
            darkAlpha: 0.14
        ),
        closeBackground: .paywall(
            light: 0xFFFFFF,
            dark: 0x10201E,
            lightAlpha: 0.82,
            darkAlpha: 0.82
        ),
        closeIcon: .paywall(light: 0x6A8C88, dark: 0xB9D1CD),
        headerTitle: .paywall(light: 0x174945, dark: 0xF3F4F6),
        headerSubtitle: .paywall(light: 0x5F7A7A, dark: 0xB5C2C0),
        counterBackground: .paywall(light: 0xE8FBF7, dark: 0x103432),
        counterBorder: .paywall(light: 0xBFE9E4, dark: 0x21504C),
        counterText: .paywall(light: 0x0F8F83, dark: 0x7AF4E2),
        counterDot: .paywall(light: 0x19B3A3, dark: 0x7AF4E2),
        statusActive: .fixed(Color(paywallRGB: 0x7AF4E2)),
        mascotCard: .paywall(light: 0xECEFED, dark: 0x11201E),
        mascotCardStroke: .paywall(
            light: 0xDDE8E4,
            dark: 0x264744,
            lightAlpha: 0.76,
            darkAlpha: 0.84
        ),
        heroTextPrimary: .paywall(light: 0xFFFFFF, dark: 0xF7FFFE),
        heroTextSecondary: .paywall(
            light: 0xFFFFFF,
            dark: 0xD7F4EF,
            lightAlpha: 0.80,
            darkAlpha: 0.82
        ),
        heroGlass: .paywall(
            light: 0xFFFFFF,
            dark: 0xFFFFFF,
            lightAlpha: 0.14,
            darkAlpha: 0.10
        ),
        heroGlassStroke: .paywall(
            light: 0xFFFFFF,
            dark: 0xD1FAE5,
            lightAlpha: 0.20,
            darkAlpha: 0.16
        ),
        cardBackground: .paywall(light: 0xFFFFFF, dark: 0x12201F),
        cardBorder: .paywall(light: 0xEDF5F3, dark: 0x28504D),
        cardTitle: .paywall(light: 0x174945, dark: 0xF3F4F6),
        cardSubtitle: .paywall(light: 0x7D9693, dark: 0xB5C2C0),
        selectedFill: .paywall(light: 0xEAF8F5, dark: 0x173331),
        selectedBorder: .paywall(
            light: 0x0F8F83,
            dark: 0x5EEAD4,
            lightAlpha: 0.72,
            darkAlpha: 0.64
        ),
        accentText: .paywall(light: 0x0F8F83, dark: 0x7AF4E2),
        lifetimeStart: .paywall(light: 0x0E3835, dark: 0x103B38),
        lifetimeMid: .paywall(light: 0x105D57, dark: 0x0F5C55),
        lifetimeEnd: .paywall(light: 0x11887F, dark: 0x159A8F),
        lifetimeHighlight: .paywall(
            light: 0x5EEAD4,
            dark: 0x7AF4E2,
            lightAlpha: 0.68,
            darkAlpha: 0.72
        ),
        ctaGradient: [
            .fixed(Color(paywallRGB: 0x35D8C7)),
            .fixed(Color(paywallRGB: 0x0F9A8D)),
            .fixed(Color(paywallRGB: 0x0B8278))
        ],
        ctaStroke: .paywall(
            light: 0xFFFFFF,
            dark: 0xD1FAE5,
            lightAlpha: 0.16,
            darkAlpha: 0.14
        ),
        ctaShadow: .fixed(Color(paywallRGB: 0x056C63)),
        shadow: .fixed(Color(paywallRGB: 0x0A786E)),
        restoreText: .paywall(light: 0x6B7280, dark: 0xAAB4B3)
    )
}

private extension AdaptiveColor {
    static func fixed(_ color: Color) -> AdaptiveColor {
        AdaptiveColor(light: color, dark: color)
    }

    static func paywall(
        light: UInt32,
        dark: UInt32,
        lightAlpha: Double = 1,
        darkAlpha: Double = 1
    ) -> AdaptiveColor {
        AdaptiveColor(
            light: Color(paywallRGB: light).opacity(lightAlpha),
            dark: Color(paywallRGB: dark).opacity(darkAlpha)
        )
    }

    func applyingOpacity(_ opacity: Double) -> AdaptiveColor {
        AdaptiveColor(
            light: light.opacity(opacity),
            dark: dark.opacity(opacity)
        )
    }
}

private extension Color {
    init(paywallRGB rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
