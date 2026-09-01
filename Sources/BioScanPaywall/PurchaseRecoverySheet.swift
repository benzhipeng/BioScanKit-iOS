import BioScanDesign
import SwiftUI

public struct PurchaseRecoverySheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var coordinator: PurchaseRecoveryCoordinator
    private let theme: BioScanTheme

    public init(
        coordinator: PurchaseRecoveryCoordinator,
        theme: BioScanTheme
    ) {
        self.coordinator = coordinator
        self.theme = theme
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gift.fill")
                .font(.title2.bold())
                .foregroundStyle(theme.accent)
                .frame(width: 48, height: 48)
                .background(theme.accent.opacity(0.12), in: .circle)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("\(coordinator.configuration.bonusCredits) free identifications")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.primaryText.resolve(for: colorScheme))

                Text("Keep exploring on us.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.secondaryText.resolve(for: colorScheme))
            }

            if let error = coordinator.lastError {
                Text(error)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.warning)
            }

            VStack(spacing: 12) {
                Button(action: claimBonus) {
                    Group {
                        if coordinator.isClaiming {
                            ProgressView().tint(.white)
                        } else {
                            Text("Claim \(coordinator.configuration.bonusCredits)")
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(.white)
                    .background(
                        theme.accent,
                        in: .rect(cornerRadius: theme.buttonCornerRadius)
                    )
                }
                .buttonStyle(.plain)
                .disabled(coordinator.isClaiming)

                Button("Not now", action: coordinator.dismissOffer)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.secondaryText.resolve(for: colorScheme))
                    .disabled(coordinator.isClaiming)
            }
        }
        .padding(24)
        .frame(maxWidth: 340)
        .background(theme.cardBackground.resolve(for: colorScheme))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.border.resolve(for: colorScheme), lineWidth: 1)
        }
        .compositingGroup()
        .clipShape(.rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        .accessibilityElement(children: .contain)
    }

    private func claimBonus() {
        Task {
            await coordinator.claimBonus()
        }
    }
}
