import BioScanDesign
import SwiftUI
import UIKit

public struct SettingsPageMetrics: Equatable, Sendable {
    public let usesTwoColumnLayout: Bool
    public let contentMaxWidth: CGFloat
    public let horizontalPadding: CGFloat
    public let columnSpacing: CGFloat

    public init(
        usesTwoColumnLayout: Bool,
        contentMaxWidth: CGFloat,
        horizontalPadding: CGFloat,
        columnSpacing: CGFloat
    ) {
        self.usesTwoColumnLayout = usesTwoColumnLayout
        self.contentMaxWidth = contentMaxWidth
        self.horizontalPadding = horizontalPadding
        self.columnSpacing = columnSpacing
    }
}

public struct SettingsPageContainer<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let versionText: String
    private let versionTapped: (@MainActor () -> Void)?
    private let content: (SettingsPageMetrics) -> Content

    public init(
        versionText: String,
        versionTapped: (@MainActor () -> Void)? = nil,
        @ViewBuilder content: @escaping (SettingsPageMetrics) -> Content
    ) {
        self.versionText = versionText
        self.versionTapped = versionTapped
        self.content = content
    }

    public var body: some View {
        GeometryReader { proxy in
            let metrics = layoutMetrics(for: proxy.size.width)

            ZStack {
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemBackground),
                        Color(uiColor: .secondarySystemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        content(metrics)

                        Button {
                            versionTapped?()
                        } label: {
                            Text(versionText)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .disabled(versionTapped == nil)
                    }
                    .frame(maxWidth: metrics.contentMaxWidth)
                    .padding(.horizontal, metrics.horizontalPadding)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func layoutMetrics(for width: CGFloat) -> SettingsPageMetrics {
        let usesTwoColumnLayout = UIDevice.current.userInterfaceIdiom == .pad
            && horizontalSizeClass == .regular
            && width >= 960
        return SettingsPageMetrics(
            usesTwoColumnLayout: usesTwoColumnLayout,
            contentMaxWidth: usesTwoColumnLayout ? 1080 : 760,
            horizontalPadding: usesTwoColumnLayout ? 24 : 18,
            columnSpacing: usesTwoColumnLayout ? 22 : 0
        )
    }
}

public struct SettingsPageView<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    private let title: String
    private let versionText: String
    private let versionTapped: (@MainActor () -> Void)?
    private let backAction: (@MainActor () -> Void)?
    private let content: (SettingsPageMetrics) -> Content

    public init(
        title: String,
        versionText: String,
        versionTapped: (@MainActor () -> Void)? = nil,
        backAction: (@MainActor () -> Void)? = nil,
        @ViewBuilder content: @escaping (SettingsPageMetrics) -> Content
    ) {
        self.title = title
        self.versionText = versionText
        self.versionTapped = versionTapped
        self.backAction = backAction
        self.content = content
    }

    public var body: some View {
        SettingsPageContainer(
            versionText: versionText,
            versionTapped: versionTapped,
            content: content
        )
        .bioScanPushNavigation(title: title)
        .navigationBarBackButtonHidden(backAction != nil)
        .toolbar {
            if let backAction {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        backAction()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 32, height: 32)
                            .background {
                                Circle()
                                    .fill(
                                        colorScheme == .dark
                                            ? Color.white.opacity(0.08)
                                            : Color.white.opacity(0.88)
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }
            }
        }
    }
}
