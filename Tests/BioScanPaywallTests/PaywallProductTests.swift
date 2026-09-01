import XCTest
@testable import BioScanPaywall

final class PaywallProductTests: XCTestCase {
    func testPurchaseActionTitleUsesCurrentCreditPlanTitle() {
        let product = PaywallProduct(
            id: "credits",
            kind: .credits(20),
            title: "Collecting",
            subtitle: "20 scans",
            actionTitle: "Choose Explorer"
        )

        XCTAssertEqual(product.purchaseActionTitle, "Get Collecting")
    }

    func testPurchaseActionTitleUsesCurrentLifetimePlanTitle() {
        let product = PaywallProduct(
            id: "lifetime",
            kind: .lifetime,
            title: "Lifetime",
            subtitle: "Unlimited scans"
        )

        XCTAssertEqual(product.purchaseActionTitle, "Unlock Lifetime")
    }
}
