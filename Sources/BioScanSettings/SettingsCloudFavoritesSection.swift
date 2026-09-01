import BioScanCloudSync
import BioScanDesign
import Foundation
import SwiftUI

public struct SettingsCloudFavoritesSectionView: View {
    @ObservedObject private var controller: CloudFavoritesSyncController
    @State private var confirmation: Confirmation?

    private let theme: BioScanTheme

    private enum Confirmation: String, Identifiable {
        case local
        case cloud

        var id: String { rawValue }
    }

    public init(controller: CloudFavoritesSyncController, theme: BioScanTheme) {
        self.controller = controller
        self.theme = theme
    }

    public var body: some View {
        SettingsSectionView("iCloud Sync", theme: theme) {
            syncControl

            SettingsDivider()

            VStack(spacing: 0) {
                CloudFavoritesActionRow(
                    icon: "iphone.slash",
                    title: "Clear on This Device",
                    subtitle: "Keeps your saved items in iCloud",
                    isEnabled: true
                ) {
                    confirmation = .local
                }

                SettingsDivider()
                    .padding(.leading, 46)

                CloudFavoritesActionRow(
                    icon: "icloud.slash.fill",
                    title: "Delete from iCloud",
                    subtitle: "Removes saved items from all synced devices",
                    isEnabled: controller.isEnabled
                ) {
                    confirmation = .cloud
                }
            }
        }
        .confirmationDialog(
            confirmation == .cloud ? "Delete saved items from iCloud?" : "Clear saved items on this device?",
            isPresented: Binding(
                get: { confirmation != nil },
                set: { if !$0 { confirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if confirmation == .cloud {
                Button("Delete on All Devices", role: .destructive) {
                    controller.deleteFavoritesFromiCloud()
                }
            } else {
                Button("Clear on This Device", role: .destructive) {
                    controller.clearFavoritesOnThisDevice()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(confirmation == .cloud
                 ? "This removes synced items from iCloud and every device using this app."
                 : "iCloud sync will be turned off. Saved items stored in iCloud will not be deleted.")
        }
    }

    private var syncControl: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "icloud.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(theme.accent, in: .rect(cornerRadius: 8))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text("Sync with iCloud")
                    .font(.system(size: 15, weight: .semibold, design: theme.fontDesign))
                    .foregroundStyle(.primary)

                CloudFavoritesStatusView(
                    presentation: statusPresentation,
                    retry: controller.retry
                )
            }

            Spacer(minLength: 8)

            Toggle("Sync Saved Items with iCloud", isOn: Binding(
                get: { controller.isEnabled },
                set: controller.setEnabled
            ))
            .labelsHidden()
            .tint(theme.accent)
            .accessibilityLabel("Sync Saved Items with iCloud")
            .accessibilityValue(controller.isEnabled ? "On" : "Off")
            .accessibilityHint("Keeps saved items up to date across devices using the same iCloud account")
        }
        .padding(.vertical, 2)
    }

    private var statusPresentation: CloudFavoritesStatusPresentation {
        switch controller.status {
        case .disabled:
            return CloudFavoritesStatusPresentation(
                title: "Stored on this device",
                icon: "iphone",
                tint: .gray
            )
        case .checkingAccount:
            return CloudFavoritesStatusPresentation(
                title: "Checking iCloud...",
                icon: nil,
                tint: theme.accent,
                isWorking: true
            )
        case .syncing:
            return CloudFavoritesStatusPresentation(
                title: "Syncing saved items...",
                icon: nil,
                tint: theme.accent,
                isWorking: true
            )
        case .synced(let date):
            return CloudFavoritesStatusPresentation(
                title: "Up to date \(date.formatted(englishDateStyle))",
                icon: "checkmark.circle.fill",
                tint: theme.success
            )
        case .unavailable:
            return CloudFavoritesStatusPresentation(
                title: "Sign in to iCloud to sync",
                icon: "exclamationmark.circle.fill",
                tint: theme.warning
            )
        case .failed(let message):
            return CloudFavoritesStatusPresentation(
                title: message,
                icon: "exclamationmark.triangle.fill",
                tint: theme.warning,
                canRetry: true
            )
        }
    }

    private var englishDateStyle: Date.FormatStyle {
        Date.FormatStyle(date: .abbreviated, time: .shortened)
            .locale(Locale(identifier: "en_US"))
    }
}

private struct CloudFavoritesStatusPresentation {
    let title: String
    let icon: String?
    let tint: Color
    var isWorking = false
    var canRetry = false
}

private struct CloudFavoritesStatusView: View {
    let presentation: CloudFavoritesStatusPresentation
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            if presentation.isWorking {
                ProgressView()
                    .controlSize(.mini)
                    .tint(presentation.tint)
                    .accessibilityHidden(true)
            } else if let icon = presentation.icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(presentation.tint)
                    .accessibilityHidden(true)
            }

            Text(presentation.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if presentation.canRetry {
                Button(action: retry) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(presentation.tint)
                        .frame(width: 28, height: 28)
                        .background(presentation.tint.opacity(0.12), in: .rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retry iCloud Sync")
                .help("Retry iCloud Sync")
            }
        }
    }
}

private struct CloudFavoritesActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isEnabled ? Color.red : Color.gray)
                    .frame(width: 34, height: 34)
                    .background(
                        (isEnabled ? Color.red : Color.gray).opacity(0.1),
                        in: .rect(cornerRadius: 8)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}
