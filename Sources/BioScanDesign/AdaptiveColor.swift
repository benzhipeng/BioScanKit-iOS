import SwiftUI

public struct AdaptiveColor: Sendable {
    public let light: Color
    public let dark: Color

    public init(light: Color, dark: Color) {
        self.light = light
        self.dark = dark
    }

    public func resolve(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? dark : light
    }
}

public extension AdaptiveColor {
    static let systemBackground = AdaptiveColor(
        light: Color(uiColor: .systemBackground),
        dark: Color(uiColor: .systemBackground)
    )

    static let secondarySystemBackground = AdaptiveColor(
        light: Color(uiColor: .secondarySystemBackground),
        dark: Color(uiColor: .secondarySystemBackground)
    )
}
