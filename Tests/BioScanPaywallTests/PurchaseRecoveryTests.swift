import XCTest
@testable import BioScanPaywall

@MainActor
final class PurchaseRecoveryTests: XCTestCase {
    func testClaimCanTriggerReviewImmediatelyOnlyOnce() async {
        let suite = "PurchaseRecoveryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let coordinator = PurchaseRecoveryCoordinator(
            appIdentifier: "test",
            defaults: defaults
        ) { _, _ in }

        coordinator.handlePurchaseCancellation(hasUnlimitedAccess: false)
        await coordinator.claimBonus()

        XCTAssertTrue(coordinator.consumeReviewRequestEligibilityAfterClaim(appVersion: "1"))
        XCTAssertFalse(coordinator.consumeReviewRequestEligibilityAfterClaim(appVersion: "1"))
        XCTAssertEqual(coordinator.currentRecord.state, .reviewRequestAttempted)
        XCTAssertEqual(coordinator.currentRecord.appVersionAtReviewAttempt, "1")
    }

    func testCancellationClaimsOnceAndUnlocksReviewAfterSuccess() async {
        let suite = "PurchaseRecoveryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var granted = 0
        let coordinator = PurchaseRecoveryCoordinator(
            appIdentifier: "test",
            defaults: defaults
        ) { amount, _ in
            granted += amount
        }

        coordinator.handlePurchaseCancellation(hasUnlimitedAccess: false)
        XCTAssertTrue(coordinator.isOfferPresented)
        await coordinator.claimBonus()
        XCTAssertEqual(granted, 10)
        XCTAssertEqual(coordinator.currentRecord.state, .claimed)
        XCTAssertFalse(coordinator.consumeReviewRequestEligibility(appVersion: "1"))

        coordinator.recordSuccessfulRecognition()
        XCTAssertTrue(coordinator.consumeReviewRequestEligibility(appVersion: "1"))
        XCTAssertFalse(coordinator.consumeReviewRequestEligibility(appVersion: "1"))

        coordinator.handlePurchaseCancellation(hasUnlimitedAccess: false)
        XCTAssertFalse(coordinator.isOfferPresented)
    }

    func testUnlimitedUserIsIneligible() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let coordinator = PurchaseRecoveryCoordinator(appIdentifier: "test", defaults: defaults) { _, _ in }
        coordinator.handlePurchaseCancellation(hasUnlimitedAccess: true)
        XCTAssertFalse(coordinator.isOfferPresented)
    }
}
