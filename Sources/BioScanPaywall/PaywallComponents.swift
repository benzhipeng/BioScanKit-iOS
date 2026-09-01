import BioScanDesign
import SwiftUI

struct PaywallTopBar: View {
    @ObservedObject var store: PaywallStore
    let theme: BioScanTheme
    let restoreTitle: String

    var body: some View {
        HStack {
            Button(action: store.dismiss) {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Spacer()

            Button(restoreTitle) {
                Task {
                    await store.restorePurchases()
                }
            }
            .font(.caption.weight(.black))
            .buttonStyle(.plain)
            .disabled(store.isBusy)
            .opacity(store.isBusy ? 0.55 : 1)
        }
        .foregroundStyle(theme.accent)
    }
}

struct StoreStatusBanner: View {
    @ObservedObject var store: PaywallStore
    let configuration: PaywallConfiguration

    var body: some View {
        HStack(spacing: 9) {
            statusIcon
                .accessibilityHidden(true)

            Text(statusText)
                .font(.caption.weight(.semibold))

            Spacer()

            if store.operation == .loadingProducts {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .foregroundStyle(statusColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(statusColor.opacity(0.10), in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch store.operation {
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
        case .loadingProducts, .purchasing, .restoring:
            Image(systemName: "arrow.triangle.2.circlepath")
        default:
            Image(systemName: "checkmark.shield.fill")
        }
    }

    private var statusText: String {
        switch store.operation {
        case .loadingProducts:
            configuration.copy.loadingStoreTitle
        case .purchasing:
            "Completing your purchase…"
        case .restoring:
            "Checking previous purchases…"
        case .succeeded:
            store.entitlement == .lifetime
                ? configuration.copy.activeLifetimeTitle
                : "Purchase complete."
        case .cancelled:
            "Purchase cancelled."
        case .failed(let message):
            message
        case .idle:
            store.products.isEmpty
                ? configuration.copy.loadingStoreTitle
                : "Secure purchase through the App Store"
        }
    }

    private var statusColor: Color {
        switch store.operation {
        case .failed:
            configuration.theme.warning
        case .succeeded:
            configuration.theme.success
        default:
            configuration.theme.accent
        }
    }
}

struct PaywallPrimaryButton: View {
    @ObservedObject var store: PaywallStore
    let configuration: PaywallConfiguration

    var body: some View {
        Button {
            if store.entitlement == .lifetime {
                store.dismiss()
            } else {
                Task {
                    await store.purchaseSelectedProduct()
                }
            }
        } label: {
            HStack(spacing: 8) {
                if store.isBusy {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                configuration.theme.accent.gradient,
                in: .rect(cornerRadius: configuration.theme.buttonCornerRadius)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
    }

    private var title: String {
        if store.entitlement == .lifetime {
            return "Continue"
        }
        guard let selected = store.selectedProduct else {
            return configuration.copy.purchaseTitle
        }
        let price = store.productDetails(for: selected.id)?.localizedPrice
        return [configuration.copy.purchaseTitle, price]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var isDisabled: Bool {
        if store.entitlement == .lifetime { return false }
        guard let selectedID = store.selectedProductID else { return true }
        return store.isBusy || store.productDetails(for: selectedID) == nil
    }
}

struct CreditBalanceBadge: View {
    let balance: CreditBalance
    let theme: BioScanTheme

    var body: some View {
        Label(balanceText, systemImage: balance.hasUnlimitedAccess ? "infinity" : "sparkles")
            .font(.caption.weight(.bold))
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(theme.accent.opacity(0.10), in: Capsule())
    }

    private var balanceText: String {
        balance.hasUnlimitedAccess
            ? "Unlimited access"
            : "\(balance.total) recognitions left"
    }
}
