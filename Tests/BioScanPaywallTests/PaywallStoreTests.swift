import XCTest
@testable import BioScanPaywall

@MainActor
final class PaywallStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "PaywallStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testConsumableWithoutTransactionIDDoesNotDeliverCredits() async {
        let store = makeStore(transactionID: nil)

        await store.load()
        await store.purchaseSelectedProduct()

        XCTAssertEqual(store.creditBalance.paid, 0)
        XCTAssertEqual(store.operation, .idle)
        XCTAssertEqual(store.notice?.title, "Purchase Failed")
        XCTAssertTrue(store.notice?.message.contains("could not be confirmed") == true)
    }

    func testConsumableWithTransactionIDIsDeliveredExactlyOnce() async {
        let store = makeStore(transactionID: "transaction-1")

        await store.load()
        await store.purchaseSelectedProduct()
        XCTAssertEqual(store.creditBalance.paid, 5)
        XCTAssertEqual(store.operation, .succeeded)

        store.clearTransientOperation()
        await store.purchaseSelectedProduct()
        XCTAssertEqual(store.creditBalance.paid, 5)
        XCTAssertEqual(store.notice?.title, "Purchase Failed")
    }

    private func makeStore(transactionID: String?) -> PaywallStore {
        let product = PaywallProduct(
            id: "credits-5",
            kind: .credits(5),
            title: "Five credits",
            subtitle: "Five identifications"
        )
        let client = ClosureBillingClient(
            loadProducts: { _ in
                [BillingProduct(id: product.id, localizedPrice: "$0.99", price: 0.99)]
            },
            purchase: { _ in
                PurchaseResult(
                    wasCancelled: false,
                    transactionID: transactionID,
                    entitlement: .standard
                )
            },
            restorePurchases: { .standard },
            refreshEntitlements: { .standard }
        )
        let ledger = CreditLedger(
            configuration: CreditStorageConfiguration(
                freeCredits: .remaining(key: "free", initialAllowance: 0),
                bonusCreditsKey: "bonus",
                paidCreditsKey: "paid",
                lifetimeCache: .boolean(key: "lifetime"),
                didSeedFreeCreditsKey: "seeded",
                processedTransactionIDsKey: "transactions"
            ),
            defaults: defaults
        )
        return PaywallStore(
            configuration: PaywallConfiguration(
                style: .iNature,
                catalog: PurchaseCatalog(
                    products: [product],
                    lifetimeProductIDs: [],
                    defaultProductID: product.id
                ),
                purchaseRecovery: nil
            ),
            billingClient: client,
            creditLedger: ledger,
            actions: PaywallActions(dismiss: {})
        )
    }
}
