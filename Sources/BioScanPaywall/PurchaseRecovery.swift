import Combine
import Foundation
import StoreKit
import UIKit

public enum PurchaseRecoveryState: String, Codable, Sendable {
    case eligible
    case offerPresented
    case offerDismissed
    case claimed
    case successfulUseCompleted
    case reviewRequestAttempted
    case ineligible
}

@MainActor
public enum PurchaseRecoveryReviewGate {
    public static func requestAfterBonusClaim(
        coordinator: PurchaseRecoveryCoordinator
    ) {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "unknown"
        guard coordinator.consumeReviewRequestEligibilityAfterClaim(appVersion: version) else {
            return
        }
        scheduleReviewRequest()
    }

    public static func recordSuccessfulRecognition(
        appIdentifier: String = Bundle.main.bundleIdentifier ?? "bioscan-app",
        configuration: PurchaseRecoveryConfiguration = .init(),
        defaults: UserDefaults = .standard
    ) {
        let coordinator = PurchaseRecoveryCoordinator(
            appIdentifier: appIdentifier,
            configuration: configuration,
            defaults: defaults
        ) { _, _ in }
        coordinator.recordSuccessfulRecognition()

        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "unknown"
        guard coordinator.consumeReviewRequestEligibility(appVersion: version) else { return }

        scheduleReviewRequest()
    }

    private static func scheduleReviewRequest() {
        Task { @MainActor in
            // Let the recovery sheet and paywall finish dismissing before StoreKit presents.
            try? await Task.sleep(for: .seconds(0.5))
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
            AppStore.requestReview(in: scene)
        }
    }
}

public struct PurchaseRecoveryConfiguration: Sendable {
    public let campaignID: String
    public let bonusCredits: Int
    public let dismissalCooldown: TimeInterval
    public let successfulUsesBeforeReviewRequest: Int

    public init(
        campaignID: String = "purchase-exit-recovery-v1",
        bonusCredits: Int = 10,
        dismissalCooldown: TimeInterval = 30 * 24 * 60 * 60,
        successfulUsesBeforeReviewRequest: Int = 1
    ) {
        self.campaignID = campaignID
        self.bonusCredits = max(1, bonusCredits)
        self.dismissalCooldown = max(0, dismissalCooldown)
        self.successfulUsesBeforeReviewRequest = max(1, successfulUsesBeforeReviewRequest)
    }
}

public struct PurchaseRecoveryRecord: Codable, Equatable, Sendable {
    public var state: PurchaseRecoveryState
    public var offerPresentedAt: Date?
    public var offerDismissedAt: Date?
    public var claimedAt: Date?
    public var grantedCredits: Int
    public var successfulUsesAfterClaim: Int
    public var reviewRequestAttemptedAt: Date?
    public var appVersionAtReviewAttempt: String?

    public init(state: PurchaseRecoveryState = .eligible) {
        self.state = state
        grantedCredits = 0
        successfulUsesAfterClaim = 0
    }
}

@MainActor
public final class PurchaseRecoveryCoordinator: ObservableObject {
    @Published public private(set) var isOfferPresented = false
    @Published public private(set) var isClaiming = false
    @Published public private(set) var lastError: String?

    public let configuration: PurchaseRecoveryConfiguration

    private let defaults: UserDefaults
    private let storageKey: String
    private let now: () -> Date
    private let grant: @MainActor (Int, String) async throws -> Void

    public init(
        appIdentifier: String,
        configuration: PurchaseRecoveryConfiguration = .init(),
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        grant: @escaping @MainActor (Int, String) async throws -> Void
    ) {
        self.configuration = configuration
        self.defaults = defaults
        self.now = now
        self.grant = grant
        storageKey = "\(appIdentifier).purchase-recovery.\(configuration.campaignID)"
    }

    public func handlePurchaseCancellation(hasUnlimitedAccess: Bool) {
        guard !hasUnlimitedAccess, canPresentOffer else { return }
        var value = record
        value.state = .offerPresented
        value.offerPresentedAt = now()
        save(value)
        isOfferPresented = true
        lastError = nil
    }

    public func dismissOffer() {
        var value = record
        guard value.state == .offerPresented else {
            isOfferPresented = false
            return
        }
        value.state = .offerDismissed
        value.offerDismissedAt = now()
        save(value)
        isOfferPresented = false
    }

    public func claimBonus() async {
        guard !isClaiming, record.state == .offerPresented else { return }
        isClaiming = true
        lastError = nil
        defer { isClaiming = false }

        do {
            try await grant(configuration.bonusCredits, configuration.campaignID)
            var value = record
            value.state = .claimed
            value.claimedAt = now()
            value.grantedCredits = configuration.bonusCredits
            save(value)
            isOfferPresented = false
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func recordSuccessfulRecognition() {
        var value = record
        guard value.state == .claimed || value.state == .successfulUseCompleted else { return }
        value.successfulUsesAfterClaim += 1
        if value.successfulUsesAfterClaim >= configuration.successfulUsesBeforeReviewRequest {
            value.state = .successfulUseCompleted
        }
        save(value)
    }

    public func consumeReviewRequestEligibility(appVersion: String) -> Bool {
        var value = record
        guard value.state == .successfulUseCompleted else { return false }
        value.state = .reviewRequestAttempted
        value.reviewRequestAttemptedAt = now()
        value.appVersionAtReviewAttempt = appVersion
        save(value)
        return true
    }

    public func consumeReviewRequestEligibilityAfterClaim(appVersion: String) -> Bool {
        var value = record
        guard value.state == .claimed else { return false }
        value.state = .reviewRequestAttempted
        value.reviewRequestAttemptedAt = now()
        value.appVersionAtReviewAttempt = appVersion
        save(value)
        return true
    }

    public var currentRecord: PurchaseRecoveryRecord { record }

    private var canPresentOffer: Bool {
        let value = record
        switch value.state {
        case .eligible:
            return true
        case .offerDismissed:
            guard let dismissedAt = value.offerDismissedAt else { return true }
            return now().timeIntervalSince(dismissedAt) >= configuration.dismissalCooldown
        default:
            return false
        }
    }

    private var record: PurchaseRecoveryRecord {
        guard let data = defaults.data(forKey: storageKey),
              let value = try? JSONDecoder().decode(PurchaseRecoveryRecord.self, from: data) else {
            return PurchaseRecoveryRecord()
        }
        return value
    }

    private func save(_ value: PurchaseRecoveryRecord) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
