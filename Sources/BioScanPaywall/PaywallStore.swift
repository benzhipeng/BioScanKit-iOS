import Combine
import Foundation

private enum PaywallStoreError: LocalizedError {
    case creditDeliveryUnconfirmed

    var errorDescription: String? {
        BioScanPaywallL10n.string("The purchase completed, but its scan credits could not be confirmed. Please contact support before purchasing again.")
    }
}

@MainActor
public final class PaywallStore: ObservableObject {
    @Published public private(set) var products: [String: BillingProduct] = [:]
    @Published public private(set) var entitlement: EntitlementState
    @Published public private(set) var creditBalance: CreditBalance
    @Published public private(set) var operation: BillingOperation = .idle
    @Published public private(set) var notice: PaywallNotice?
    @Published public var selectedProductID: String?

    public let configuration: PaywallConfiguration
    public let recoveryCoordinator: PurchaseRecoveryCoordinator?

    private let billingClient: any BillingClient
    private let creditLedger: CreditLedger
    private let actions: PaywallActions

    public init(
        configuration: PaywallConfiguration,
        billingClient: any BillingClient,
        creditLedger: CreditLedger,
        actions: PaywallActions
    ) {
        self.configuration = configuration
        self.billingClient = billingClient
        self.creditLedger = creditLedger
        self.actions = actions
        if let recoveryConfiguration = configuration.purchaseRecovery {
            recoveryCoordinator = PurchaseRecoveryCoordinator(
                appIdentifier: Bundle.main.bundleIdentifier ?? "bioscan-app",
                configuration: recoveryConfiguration
            ) { amount, campaignID in
                _ = creditLedger.grantRecoveryCredits(amount, campaignID: campaignID)
                actions.syncCreditBalance()
            }
        } else {
            recoveryCoordinator = nil
        }
        creditBalance = creditLedger.balance
        entitlement = creditLedger.balance.hasUnlimitedAccess ? .lifetime : .unknown
        selectedProductID = configuration.catalog.defaultProductID
    }

    public var selectedProduct: PaywallProduct? {
        guard let selectedProductID else { return nil }
        return configuration.catalog.product(id: selectedProductID)
    }

    public var isBusy: Bool {
        switch operation {
        case .loadingProducts, .purchasing, .restoring:
            return true
        default:
            return false
        }
    }

    public func productDetails(for id: String) -> BillingProduct? {
        products[id]
    }

    public func localizedOriginalPrice(for id: String) -> String? {
        products[id]?.localizedPrice(multipliedBy: 2)
    }

    public func appeared() {
        actions.track(.shown(configuration.style))
    }

    public func select(_ productID: String) {
        guard configuration.catalog.product(id: productID) != nil else { return }
        selectedProductID = productID
        actions.track(.productSelected(productID))
    }

    public func load() async {
        notice = nil
        operation = .loadingProducts
        do {
            async let loadedProducts = billingClient.loadProducts(
                identifiers: configuration.catalog.products.map(\.id)
            )
            async let refreshedEntitlement = billingClient.refreshEntitlements()
            let (productsResult, entitlementResult) = try await (
                loadedProducts,
                refreshedEntitlement
            )

            products = Dictionary(
                productsResult.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            apply(entitlement: entitlementResult)
            operation = .idle
        } catch {
            operation = .failed(message: error.localizedDescription)
        }
    }

    public func purchaseSelectedProduct() async {
        guard let product = selectedProduct else { return }
        guard products[product.id] != nil else {
            operation = .idle
            notice = PaywallNotice(
                title: "Connecting to Store",
                message: "Products are still loading. Please wait a moment and try again."
            )
            return
        }

        notice = nil
        actions.track(.purchaseStarted(product.id))
        operation = .purchasing(productID: product.id)

        do {
            let result = try await billingClient.purchase(productID: product.id)
            if result.wasCancelled {
                operation = .cancelled
                actions.track(.purchaseCancelled(product.id))
                recoveryCoordinator?.handlePurchaseCancellation(
                    hasUnlimitedAccess: creditLedger.balance.hasUnlimitedAccess
                )
                return
            }

            switch product.kind {
            case .lifetime:
                apply(entitlement: .lifetime)
            case .credits(let amount):
                if configuration.creditAccounting == .ledger {
                    guard creditLedger.addPurchasedCredits(
                        amount,
                        transactionID: result.transactionID
                    ) else {
                        throw PaywallStoreError.creditDeliveryUnconfirmed
                    }
                }
                creditBalance = creditLedger.balance
            }

            if result.entitlement == .lifetime {
                apply(entitlement: .lifetime)
            }

            operation = .succeeded
            actions.track(.purchaseSucceeded(product.id))
        } catch {
            operation = .idle
            notice = PaywallNotice(
                title: "Purchase Failed",
                message: error.localizedDescription
            )
            actions.track(.purchaseFailed(product.id))
        }
    }

    public func restorePurchases() async {
        notice = nil
        actions.track(.restoreStarted)
        operation = .restoring

        do {
            let restored = try await billingClient.restorePurchases()
            apply(entitlement: restored)
            if restored == .lifetime {
                operation = .succeeded
                actions.track(.restoreSucceeded)
            } else {
                operation = .idle
                notice = PaywallNotice(
                    title: "Restore",
                    message: "No previous Lifetime purchase found."
                )
                actions.track(.restoreNothingFound)
            }
        } catch {
            operation = .idle
            notice = PaywallNotice(
                title: "Restore Failed",
                message: error.localizedDescription
            )
            actions.track(.restoreFailed)
        }
    }

    public func dismiss() {
        actions.dismiss()
    }

    public func refreshCreditBalance() {
        creditBalance = creditLedger.balance
    }

    public func clearTransientOperation() {
        switch operation {
        case .succeeded, .cancelled, .failed:
            operation = .idle
        default:
            break
        }
    }

    public func clearNotice() {
        notice = nil
    }

    private func apply(entitlement newValue: EntitlementState) {
        entitlement = newValue
        creditLedger.setLifetime(newValue == .lifetime)
        creditBalance = creditLedger.balance
    }
}
