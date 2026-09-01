import Foundation

@MainActor
public protocol BillingClient: AnyObject {
    func loadProducts(identifiers: [String]) async throws -> [BillingProduct]
    func purchase(productID: String) async throws -> PurchaseResult
    func restorePurchases() async throws -> EntitlementState
    func refreshEntitlements() async throws -> EntitlementState
}

@MainActor
public final class ClosureBillingClient: BillingClient {
    private let loadProductsClosure: ([String]) async throws -> [BillingProduct]
    private let purchaseClosure: (String) async throws -> PurchaseResult
    private let restoreClosure: () async throws -> EntitlementState
    private let refreshClosure: () async throws -> EntitlementState

    public init(
        loadProducts: @escaping ([String]) async throws -> [BillingProduct],
        purchase: @escaping (String) async throws -> PurchaseResult,
        restorePurchases: @escaping () async throws -> EntitlementState,
        refreshEntitlements: @escaping () async throws -> EntitlementState
    ) {
        loadProductsClosure = loadProducts
        purchaseClosure = purchase
        restoreClosure = restorePurchases
        refreshClosure = refreshEntitlements
    }

    public func loadProducts(identifiers: [String]) async throws -> [BillingProduct] {
        try await loadProductsClosure(identifiers)
    }

    public func purchase(productID: String) async throws -> PurchaseResult {
        try await purchaseClosure(productID)
    }

    public func restorePurchases() async throws -> EntitlementState {
        try await restoreClosure()
    }

    public func refreshEntitlements() async throws -> EntitlementState {
        try await refreshClosure()
    }
}
