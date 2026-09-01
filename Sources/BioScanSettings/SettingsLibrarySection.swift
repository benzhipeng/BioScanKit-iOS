import BioScanDesign
import SwiftUI

public struct SettingsLibraryCopy: Sendable {
    public let sectionTitle: String
    public let historyTitle: String
    public let historySubtitle: String
    public let historyIcon: String
    public let clearHistoryTitle: String
    public let clearConfirmationTitle: String
    public let clearConfirmationMessage: String
    public let clearActionTitle: String

    public init(
        sectionTitle: String = "Data",
        historyTitle: String = "Scan History",
        historySubtitle: String,
        historyIcon: String = "clock.fill",
        clearHistoryTitle: String = "Clear All History",
        clearConfirmationTitle: String = "Clear all history?",
        clearConfirmationMessage: String = "This will remove all scan records and cached images.",
        clearActionTitle: String = "Clear"
    ) {
        self.sectionTitle = sectionTitle
        self.historyTitle = historyTitle
        self.historySubtitle = historySubtitle
        self.historyIcon = historyIcon
        self.clearHistoryTitle = clearHistoryTitle
        self.clearConfirmationTitle = clearConfirmationTitle
        self.clearConfirmationMessage = clearConfirmationMessage
        self.clearActionTitle = clearActionTitle
    }
}

/// Shared settings entry point for app-owned scan history.
///
/// The package owns only the row layout and navigation interaction. Each app
/// supplies its existing destinations so its domain models and persistence stay
/// outside BioScanKit.
public struct SettingsLibrarySectionView<HistoryDestination: View>: View {
    @State private var showsClearConfirmation = false

    private let copy: SettingsLibraryCopy
    private let theme: BioScanTheme
    private let isHistoryEmpty: Bool
    private let clearHistory: (() -> Void)?
    private let historyDestination: HistoryDestination

    public init(
        copy: SettingsLibraryCopy,
        theme: BioScanTheme,
        isHistoryEmpty: Bool = false,
        clearHistory: (() -> Void)? = nil,
        @ViewBuilder historyDestination: () -> HistoryDestination
    ) {
        self.copy = copy
        self.theme = theme
        self.isHistoryEmpty = isHistoryEmpty
        self.clearHistory = clearHistory
        self.historyDestination = historyDestination()
    }

    public var body: some View {
        SettingsSectionView(copy.sectionTitle, theme: theme) {
            NavigationLink {
                historyDestination
            } label: {
                SettingsNavigationRowView(
                    icon: copy.historyIcon,
                    title: copy.historyTitle,
                    subtitle: copy.historySubtitle,
                    theme: theme
                )
            }
            .buttonStyle(.plain)

            if clearHistory != nil {
                SettingsDivider()

                Button {
                    showsClearConfirmation = true
                } label: {
                    Label(copy.clearHistoryTitle, systemImage: "trash.fill")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(isHistoryEmpty)
                .opacity(isHistoryEmpty ? 0.5 : 1)
            }
        }
        .confirmationDialog(copy.clearConfirmationTitle, isPresented: $showsClearConfirmation) {
            Button(copy.clearActionTitle, role: .destructive) {
                clearHistory?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(copy.clearConfirmationMessage)
        }
    }
}
