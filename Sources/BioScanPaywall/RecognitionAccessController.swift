import Foundation

/// Coordinates recognition access and credit consumption for app recognition flows.
/// The operation is expected to perform validation and begin the real model work.
@MainActor
public final class RecognitionAccessController {
    public enum AccessError: LocalizedError, Equatable {
        case noCredits
        case busy

        public var errorDescription: String? {
            switch self {
            case .noCredits:
                return BioScanPaywallL10n.string("No identifications remaining.")
            case .busy:
                return BioScanPaywallL10n.string("An identification is already in progress.")
            }
        }
    }

    private let ledger: CreditLedger
    private var isBusy = false

    public init(ledger: CreditLedger) {
        self.ledger = ledger
    }

    public var balance: CreditBalance { ledger.balance }
    public var hasAccess: Bool { ledger.balance.hasUnlimitedAccess || ledger.balance.total > 0 }

    /// Consumes one credit only after the operation successfully begins.
    /// Validation should happen before calling this method.
    public func perform<Result>(operation: () async throws -> Result) async throws -> Result {
        guard !isBusy else { throw AccessError.busy }
        guard ledger.balance.hasUnlimitedAccess || ledger.balance.total > 0 else {
            throw AccessError.noCredits
        }

        isBusy = true
        defer { isBusy = false }
        let result = try await operation()
        guard ledger.consumeOneCredit() else { throw AccessError.noCredits }
        return result
    }
}
