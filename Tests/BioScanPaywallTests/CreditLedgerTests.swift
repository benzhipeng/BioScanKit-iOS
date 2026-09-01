import XCTest
@testable import BioScanPaywall

@MainActor
final class CreditLedgerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "BioScanKitTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRemainingCreditsAreSeededAndConsumed() {
        let ledger = CreditLedger(
            configuration: configuration(
                freeCredits: .remaining(key: "free", initialAllowance: 5)
            ),
            defaults: defaults
        )

        XCTAssertEqual(ledger.balance.free, 5)
        XCTAssertTrue(ledger.consumeOneCredit())
        XCTAssertEqual(ledger.balance.free, 4)
    }

    func testUsedCountStoragePreservesINatureSemantics() {
        defaults.set(2, forKey: "used")
        let ledger = CreditLedger(
            configuration: configuration(
                freeCredits: .used(key: "used", allowance: 5)
            ),
            defaults: defaults
        )

        XCTAssertEqual(ledger.balance.free, 3)
        XCTAssertTrue(ledger.consumeOneCredit())
        XCTAssertEqual(defaults.integer(forKey: "used"), 3)
    }

    func testUpgradePreservesExistingRemainingBalanceWhenSeedFlagExists() {
        defaults.set(2, forKey: "free")
        defaults.set(true, forKey: "seeded")
        defaults.set(7, forKey: "paid")

        let ledger = CreditLedger(
            configuration: configuration(
                freeCredits: .remaining(key: "free", initialAllowance: 5)
            ),
            defaults: defaults
        )

        XCTAssertEqual(ledger.balance.free, 2)
        XCTAssertEqual(ledger.balance.paid, 7)
    }

    func testUpgradePreservesExistingRemainingBalanceWhenSeedFlagIsNew() {
        defaults.set(0, forKey: "free")
        defaults.set(7, forKey: "paid")

        let ledger = CreditLedger(
            configuration: configuration(
                freeCredits: .remaining(key: "free", initialAllowance: 5)
            ),
            defaults: defaults
        )

        XCTAssertEqual(ledger.balance.free, 0)
        XCTAssertEqual(ledger.balance.paid, 7)
        XCTAssertTrue(defaults.bool(forKey: "seeded"))
    }

    func testUpgradePreservesLifetimeStringCache() {
        defaults.set("lifetime", forKey: "membership")
        let ledger = CreditLedger(
            configuration: configuration(
                freeCredits: .used(key: "used", allowance: 5)
            ),
            defaults: defaults
        )

        XCTAssertTrue(ledger.balance.hasUnlimitedAccess)
        XCTAssertTrue(ledger.consumeOneCredit())
        XCTAssertEqual(defaults.integer(forKey: "used"), 0)
    }

    func testTransactionIDPreventsDuplicateCredit() {
        let ledger = CreditLedger(
            configuration: configuration(
                freeCredits: .remaining(key: "free", initialAllowance: 0)
            ),
            defaults: defaults
        )

        XCTAssertTrue(ledger.addPurchasedCredits(5, transactionID: "transaction-1"))
        XCTAssertFalse(ledger.addPurchasedCredits(5, transactionID: "transaction-1"))
        XCTAssertEqual(ledger.balance.paid, 5)
    }

    func testPurchasedCreditsRequireStableTransactionID() {
        let ledger = CreditLedger(
            configuration: configuration(
                freeCredits: .remaining(key: "free", initialAllowance: 0)
            ),
            defaults: defaults
        )

        XCTAssertFalse(ledger.addPurchasedCredits(5, transactionID: nil))
        XCTAssertFalse(ledger.addPurchasedCredits(5, transactionID: ""))
        XCTAssertFalse(ledger.addPurchasedCredits(5, transactionID: "  \n"))
        XCTAssertEqual(ledger.balance.paid, 0)
    }

    func testPurchasedCreditsRejectIntegerOverflowWithoutMarkingTransaction() {
        defaults.set(Int.max, forKey: "paid")
        let ledger = CreditLedger(
            configuration: configuration(
                freeCredits: .remaining(key: "free", initialAllowance: 0)
            ),
            defaults: defaults
        )

        XCTAssertFalse(ledger.addPurchasedCredits(1, transactionID: "overflow"))
        XCTAssertEqual(ledger.balance.paid, Int.max)
        XCTAssertFalse((defaults.stringArray(forKey: "transactions") ?? []).contains("overflow"))
    }

    func testRecoveryCreditsUseBonusBucketAndAreConsumedBeforePaidCredits() {
        let ledger = CreditLedger(
            configuration: configuration(
                freeCredits: .remaining(key: "free", initialAllowance: 0)
            ),
            defaults: defaults
        )

        XCTAssertTrue(ledger.addPurchasedCredits(5, transactionID: "transaction-1"))
        XCTAssertTrue(ledger.grantRecoveryCredits(10, campaignID: "recovery-v1"))
        XCTAssertFalse(ledger.grantRecoveryCredits(10, campaignID: "recovery-v1"))
        XCTAssertEqual(ledger.balance.bonus, 10)
        XCTAssertEqual(ledger.balance.paid, 5)

        XCTAssertTrue(ledger.consumeOneCredit())
        XCTAssertEqual(ledger.balance.bonus, 9)
        XCTAssertEqual(ledger.balance.paid, 5)
    }

    func testRecoveryCreditsRequireCampaignID() {
        let ledger = CreditLedger(
            configuration: configuration(
                freeCredits: .remaining(key: "free", initialAllowance: 0)
            ),
            defaults: defaults
        )

        XCTAssertFalse(ledger.grantRecoveryCredits(10, campaignID: " \n"))
        XCTAssertEqual(ledger.balance.bonus, 0)
    }

    func testLifetimeStringCache() {
        let ledger = CreditLedger(
            configuration: configuration(
                freeCredits: .remaining(key: "free", initialAllowance: 0)
            ),
            defaults: defaults
        )

        ledger.setLifetime(true)
        XCTAssertTrue(ledger.balance.hasUnlimitedAccess)
        XCTAssertEqual(defaults.string(forKey: "membership"), "lifetime")
    }

    func testLifetimeDoesNotConsumeAnyCreditBucket() {
        let ledger = CreditLedger(
            configuration: configuration(
                freeCredits: .remaining(key: "free", initialAllowance: 5)
            ),
            defaults: defaults
        )
        XCTAssertTrue(ledger.grantRecoveryCredits(10, campaignID: "recovery-v1"))
        XCTAssertTrue(ledger.addPurchasedCredits(5, transactionID: "transaction-1"))
        ledger.setLifetime(true)

        XCTAssertTrue(ledger.consumeOneCredit())
        XCTAssertEqual(ledger.balance.free, 5)
        XCTAssertEqual(ledger.balance.bonus, 10)
        XCTAssertEqual(ledger.balance.paid, 5)
    }

    private func configuration(
        freeCredits: FreeCreditStorage
    ) -> CreditStorageConfiguration {
        CreditStorageConfiguration(
            freeCredits: freeCredits,
            bonusCreditsKey: "bonus",
            paidCreditsKey: "paid",
            lifetimeCache: .string(key: "membership", lifetimeValue: "lifetime"),
            didSeedFreeCreditsKey: "seeded",
            processedTransactionIDsKey: "transactions"
        )
    }
}
