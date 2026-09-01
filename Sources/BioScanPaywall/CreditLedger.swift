import Foundation

public enum FreeCreditStorage: Sendable {
    case remaining(key: String, initialAllowance: Int)
    case used(key: String, allowance: Int)
}

public enum LifetimeCacheStorage: Sendable {
    case boolean(key: String)
    case string(key: String, lifetimeValue: String)
}

public struct CreditStorageConfiguration: Sendable {
    public let freeCredits: FreeCreditStorage
    public let bonusCreditsKey: String
    public let paidCreditsKey: String
    public let lifetimeCache: LifetimeCacheStorage
    public let didSeedFreeCreditsKey: String?
    public let processedTransactionIDsKey: String
    public let legacyBonusCreditsKey: String?
    public let legacyBonusMigrationKey: String?

    public init(
        freeCredits: FreeCreditStorage,
        bonusCreditsKey: String = "bioscan.billing.bonus_remaining",
        paidCreditsKey: String,
        lifetimeCache: LifetimeCacheStorage,
        didSeedFreeCreditsKey: String? = nil,
        processedTransactionIDsKey: String,
        legacyBonusCreditsKey: String? = nil,
        legacyBonusMigrationKey: String? = nil
    ) {
        self.freeCredits = freeCredits
        self.bonusCreditsKey = bonusCreditsKey
        self.paidCreditsKey = paidCreditsKey
        self.lifetimeCache = lifetimeCache
        self.didSeedFreeCreditsKey = didSeedFreeCreditsKey
        self.processedTransactionIDsKey = processedTransactionIDsKey
        self.legacyBonusCreditsKey = legacyBonusCreditsKey
        self.legacyBonusMigrationKey = legacyBonusMigrationKey
    }
}

@MainActor
public final class CreditLedger {
    private let defaults: UserDefaults
    private let configuration: CreditStorageConfiguration

    public init(
        configuration: CreditStorageConfiguration,
        defaults: UserDefaults = .standard
    ) {
        self.configuration = configuration
        self.defaults = defaults
        seedFreeCreditsIfNeeded()
        migrateLegacyBonusCreditsIfNeeded()
    }

    public var balance: CreditBalance {
        CreditBalance(
            free: freeCredits,
            bonus: max(0, defaults.integer(forKey: configuration.bonusCreditsKey)),
            paid: max(0, defaults.integer(forKey: configuration.paidCreditsKey)),
            hasUnlimitedAccess: cachedLifetime
        )
    }

    @discardableResult
    public func addPurchasedCredits(
        _ amount: Int,
        transactionID: String?
    ) -> Bool {
        guard amount > 0 else { return false }
        guard let transactionID else { return false }
        let normalizedTransactionID = transactionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTransactionID.isEmpty else { return false }

        var processed = Set(
            defaults.stringArray(
                forKey: configuration.processedTransactionIDsKey
            ) ?? []
        )
        guard processed.insert(normalizedTransactionID).inserted else { return false }

        let current = max(0, defaults.integer(forKey: configuration.paidCreditsKey))
        let (updated, overflow) = current.addingReportingOverflow(amount)
        guard !overflow else { return false }
        defaults.set(updated, forKey: configuration.paidCreditsKey)
        defaults.set(
            Array(processed).sorted(),
            forKey: configuration.processedTransactionIDsKey
        )
        return true
    }

    @discardableResult
    public func grantRecoveryCredits(
        _ amount: Int,
        campaignID: String
    ) -> Bool {
        guard amount > 0 else { return false }
        let normalizedCampaignID = campaignID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedCampaignID.isEmpty else { return false }
        var processed = Set(
            defaults.stringArray(forKey: configuration.processedTransactionIDsKey) ?? []
        )
        guard processed.insert("recovery:\(normalizedCampaignID)").inserted else { return false }
        let current = max(0, defaults.integer(forKey: configuration.bonusCreditsKey))
        let (updated, overflow) = current.addingReportingOverflow(amount)
        guard !overflow else { return false }
        defaults.set(updated, forKey: configuration.bonusCreditsKey)
        defaults.set(Array(processed).sorted(), forKey: configuration.processedTransactionIDsKey)
        return true
    }

    public func consumeOneCredit() -> Bool {
        guard !cachedLifetime else { return true }

        if freeCredits > 0 {
            switch configuration.freeCredits {
            case .remaining(let key, _):
                defaults.set(max(0, defaults.integer(forKey: key) - 1), forKey: key)
            case .used(let key, let allowance):
                let used = min(max(defaults.integer(forKey: key), 0), allowance)
                defaults.set(used + 1, forKey: key)
            }
            return true
        }

        let bonus = max(0, defaults.integer(forKey: configuration.bonusCreditsKey))
        if bonus > 0 {
            defaults.set(bonus - 1, forKey: configuration.bonusCreditsKey)
            return true
        }

        let paid = max(0, defaults.integer(forKey: configuration.paidCreditsKey))
        guard paid > 0 else { return false }
        defaults.set(paid - 1, forKey: configuration.paidCreditsKey)
        return true
    }

    public func setLifetime(_ isActive: Bool) {
        switch configuration.lifetimeCache {
        case .boolean(let key):
            defaults.set(isActive, forKey: key)
        case .string(let key, let lifetimeValue):
            if isActive {
                defaults.set(lifetimeValue, forKey: key)
            } else if defaults.string(forKey: key) == lifetimeValue {
                defaults.removeObject(forKey: key)
            }
        }
    }

    private var freeCredits: Int {
        switch configuration.freeCredits {
        case .remaining(let key, _):
            return max(0, defaults.integer(forKey: key))
        case .used(let key, let allowance):
            return max(0, allowance - max(0, defaults.integer(forKey: key)))
        }
    }

    private var cachedLifetime: Bool {
        switch configuration.lifetimeCache {
        case .boolean(let key):
            return defaults.bool(forKey: key)
        case .string(let key, let lifetimeValue):
            return defaults.string(forKey: key) == lifetimeValue
        }
    }

    private func migrateLegacyBonusCreditsIfNeeded() {
        guard
            let bonusKey = configuration.legacyBonusCreditsKey,
            let migrationKey = configuration.legacyBonusMigrationKey,
            !defaults.bool(forKey: migrationKey)
        else { return }

        let bonus = max(0, defaults.integer(forKey: bonusKey))
        let paid = max(0, defaults.integer(forKey: configuration.paidCreditsKey))
        let (updatedPaid, overflow) = paid.addingReportingOverflow(bonus)
        guard !overflow else { return }

        defaults.set(updatedPaid, forKey: configuration.paidCreditsKey)
        defaults.removeObject(forKey: bonusKey)
        defaults.set(true, forKey: migrationKey)
    }

    private func seedFreeCreditsIfNeeded() {
        guard case .remaining(let key, let allowance) = configuration.freeCredits else {
            return
        }

        if let seedKey = configuration.didSeedFreeCreditsKey {
            guard !defaults.bool(forKey: seedKey) else { return }
            // Upgrade compatibility: an older build may already own this balance key but not
            // the newer seed marker. Never refill or overwrite that existing balance.
            if defaults.object(forKey: key) == nil {
                defaults.set(max(0, allowance), forKey: key)
            }
            defaults.set(true, forKey: seedKey)
        } else if defaults.object(forKey: key) == nil {
            defaults.set(max(0, allowance), forKey: key)
        }
    }
}
