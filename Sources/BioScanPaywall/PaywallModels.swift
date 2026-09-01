import BioScanDesign
import SwiftUI

public enum PaywallStyle: Sendable {
    case iNature
    case cardSelection
}

public enum CardSelectionPaywallAppearance: Sendable {
    case themed
    case legacyRock
}

/// Visual tokens for the selectable-card paywall layout.
///
/// Apps can keep the shared Rock-style composition while supplying their own
/// exact light/dark palette and hero geometry.
public struct CardSelectionPaywallTheme: Sendable {
    public let backgroundGradient: [AdaptiveColor]
    public let glowStrong: AdaptiveColor
    public let glowSoft: AdaptiveColor
    public let closeBackground: AdaptiveColor
    public let closeIcon: AdaptiveColor
    public let headerTitle: AdaptiveColor
    public let headerSubtitle: AdaptiveColor
    public let counterBackground: AdaptiveColor
    public let counterBorder: AdaptiveColor
    public let counterText: AdaptiveColor
    public let counterDot: AdaptiveColor
    public let statusActive: AdaptiveColor
    public let mascotCard: AdaptiveColor
    public let mascotCardStroke: AdaptiveColor
    public let heroTextPrimary: AdaptiveColor
    public let heroTextSecondary: AdaptiveColor
    public let heroGlass: AdaptiveColor
    public let heroGlassStroke: AdaptiveColor
    public let cardBackground: AdaptiveColor
    public let cardBorder: AdaptiveColor
    public let cardTitle: AdaptiveColor
    public let cardSubtitle: AdaptiveColor
    public let selectedFill: AdaptiveColor
    public let selectedBorder: AdaptiveColor
    public let accentText: AdaptiveColor
    public let lifetimeStart: AdaptiveColor
    public let lifetimeMid: AdaptiveColor
    public let lifetimeEnd: AdaptiveColor
    public let lifetimeHighlight: AdaptiveColor
    public let ctaGradient: [AdaptiveColor]
    public let ctaStroke: AdaptiveColor
    public let ctaShadow: AdaptiveColor
    public let shadow: AdaptiveColor
    public let restoreText: AdaptiveColor
    public let heroSize: CGSize
    public let heroCornerRadius: CGFloat

    public init(
        backgroundGradient: [AdaptiveColor],
        glowStrong: AdaptiveColor,
        glowSoft: AdaptiveColor,
        closeBackground: AdaptiveColor,
        closeIcon: AdaptiveColor,
        headerTitle: AdaptiveColor,
        headerSubtitle: AdaptiveColor,
        counterBackground: AdaptiveColor,
        counterBorder: AdaptiveColor,
        counterText: AdaptiveColor,
        counterDot: AdaptiveColor,
        statusActive: AdaptiveColor,
        mascotCard: AdaptiveColor,
        mascotCardStroke: AdaptiveColor,
        heroTextPrimary: AdaptiveColor,
        heroTextSecondary: AdaptiveColor,
        heroGlass: AdaptiveColor,
        heroGlassStroke: AdaptiveColor,
        cardBackground: AdaptiveColor,
        cardBorder: AdaptiveColor,
        cardTitle: AdaptiveColor,
        cardSubtitle: AdaptiveColor,
        selectedFill: AdaptiveColor,
        selectedBorder: AdaptiveColor,
        accentText: AdaptiveColor,
        lifetimeStart: AdaptiveColor,
        lifetimeMid: AdaptiveColor,
        lifetimeEnd: AdaptiveColor,
        lifetimeHighlight: AdaptiveColor,
        ctaGradient: [AdaptiveColor],
        ctaStroke: AdaptiveColor,
        ctaShadow: AdaptiveColor,
        shadow: AdaptiveColor,
        restoreText: AdaptiveColor,
        heroSize: CGSize = CGSize(width: 168, height: 94.5),
        heroCornerRadius: CGFloat = 26
    ) {
        self.backgroundGradient = backgroundGradient
        self.glowStrong = glowStrong
        self.glowSoft = glowSoft
        self.closeBackground = closeBackground
        self.closeIcon = closeIcon
        self.headerTitle = headerTitle
        self.headerSubtitle = headerSubtitle
        self.counterBackground = counterBackground
        self.counterBorder = counterBorder
        self.counterText = counterText
        self.counterDot = counterDot
        self.statusActive = statusActive
        self.mascotCard = mascotCard
        self.mascotCardStroke = mascotCardStroke
        self.heroTextPrimary = heroTextPrimary
        self.heroTextSecondary = heroTextSecondary
        self.heroGlass = heroGlass
        self.heroGlassStroke = heroGlassStroke
        self.cardBackground = cardBackground
        self.cardBorder = cardBorder
        self.cardTitle = cardTitle
        self.cardSubtitle = cardSubtitle
        self.selectedFill = selectedFill
        self.selectedBorder = selectedBorder
        self.accentText = accentText
        self.lifetimeStart = lifetimeStart
        self.lifetimeMid = lifetimeMid
        self.lifetimeEnd = lifetimeEnd
        self.lifetimeHighlight = lifetimeHighlight
        self.ctaGradient = ctaGradient
        self.ctaStroke = ctaStroke
        self.ctaShadow = ctaShadow
        self.shadow = shadow
        self.restoreText = restoreText
        self.heroSize = heroSize
        self.heroCornerRadius = heroCornerRadius
    }
}

public enum INaturePaywallLayoutStyle: Sendable {
    /// Generic lifetime-and-credits presentation for apps sharing the iNature family.
    case standard
    /// Pixel-aligned presentation matching the original iNature purchase page.
    case legacyINature
    /// Presentation matching NatureEar's original warm field-kit purchase page.
    case legacyNatureEar
}

public enum PaywallProductKind: Equatable, Sendable {
    case lifetime
    case credits(Int)
}

public struct PaywallProduct: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: PaywallProductKind
    public let title: String
    public let subtitle: String
    public let badge: String?
    public let actionTitle: String?
    public let unitSuffix: String?
    public let footerText: String?

    /// Shared CTA copy derived from the selected product, keeping the button
    /// synchronized when an app renames a plan.
    public var purchaseActionTitle: String {
        switch kind {
        case .credits:
            return "Get \(title)"
        case .lifetime:
            return "Unlock \(title)"
        }
    }

    public init(
        id: String,
        kind: PaywallProductKind,
        title: String,
        subtitle: String,
        badge: String? = nil,
        actionTitle: String? = nil,
        unitSuffix: String? = nil,
        footerText: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.actionTitle = actionTitle
        self.unitSuffix = unitSuffix
        self.footerText = footerText
    }
}

public struct PurchaseCatalog: Sendable {
    public let products: [PaywallProduct]
    public let lifetimeProductIDs: Set<String>
    public let defaultProductID: String

    public init(
        products: [PaywallProduct],
        lifetimeProductIDs: Set<String>,
        defaultProductID: String
    ) {
        self.products = products
        self.lifetimeProductIDs = lifetimeProductIDs
        self.defaultProductID = defaultProductID
    }

    public func product(id: String) -> PaywallProduct? {
        products.first { $0.id == id }
    }
}

public struct PaywallCopy: Sendable {
    public let title: String
    public let subtitle: String
    public let lifetimeSectionTitle: String
    public let creditSectionTitle: String
    public let assuranceTitle: String
    public let assuranceItems: [String]
    public let restoreTitle: String
    public let purchaseTitle: String
    public let purchasePriceSeparator: String
    public let activeLifetimeTitle: String
    public let loadingStoreTitle: String
    public let noProductsTitle: String

    public init(
        title: String = "Identify More. Explore Forever.",
        subtitle: String = "Pay once for lifetime access, or add recognition credits whenever you need them.",
        lifetimeSectionTitle: String = "Lifetime Access",
        creditSectionTitle: String = "Recognition Credits",
        assuranceTitle: String = "Purchase with confidence",
        assuranceItems: [String] = [
            "One-time purchases",
            "No subscription",
            "Restore lifetime access anytime"
        ],
        restoreTitle: String = "RESTORE",
        purchaseTitle: String = "Continue",
        purchasePriceSeparator: String = " — ",
        activeLifetimeTitle: String = "Lifetime Access Active",
        loadingStoreTitle: String = "Connecting to the App Store…",
        noProductsTitle: String = "Products are currently unavailable."
    ) {
        self.title = title
        self.subtitle = subtitle
        self.lifetimeSectionTitle = lifetimeSectionTitle
        self.creditSectionTitle = creditSectionTitle
        self.assuranceTitle = assuranceTitle
        self.assuranceItems = assuranceItems
        self.restoreTitle = restoreTitle
        self.purchaseTitle = purchaseTitle
        self.purchasePriceSeparator = purchasePriceSeparator
        self.activeLifetimeTitle = activeLifetimeTitle
        self.loadingStoreTitle = loadingStoreTitle
        self.noProductsTitle = noProductsTitle
    }

    public static let iNature = PaywallCopy(
        title: "Your offline scanner",
        subtitle: "Perfect for hikes, camping, and travel without signal",
        assuranceTitle: "All yours — no subscription hassle!",
        assuranceItems: [
            "Unlimited toxicity scans",
            "Instant AI recognition",
            "Offline database access",
            "Expert-verified reports",
            "Continuous optimization"
        ]
    )
}

public struct PaywallFeatures: Sendable {
    public let showsSavings: Bool
    public let showsAssurance: Bool
    public let showsCreditBalance: Bool
    public let showsOriginalPrice: Bool
    public let automaticallySelectLifetime: Bool

    public init(
        showsSavings: Bool = true,
        showsAssurance: Bool = true,
        showsCreditBalance: Bool = true,
        showsOriginalPrice: Bool = true,
        automaticallySelectLifetime: Bool = true
    ) {
        self.showsSavings = showsSavings
        self.showsAssurance = showsAssurance
        self.showsCreditBalance = showsCreditBalance
        self.showsOriginalPrice = showsOriginalPrice
        self.automaticallySelectLifetime = automaticallySelectLifetime
    }

    public static let iNature = PaywallFeatures()
    public static let cardSelectionDefaults = PaywallFeatures(
        showsSavings: true,
        showsAssurance: false,
        showsCreditBalance: true,
        showsOriginalPrice: true,
        automaticallySelectLifetime: true
    )
}

public enum CreditAccounting: Equatable, Sendable {
    /// BioScanKit records consumable credits after a successful purchase.
    case ledger
    /// The injected BillingClient updates the app's existing credit store.
    case billingClient
}

public struct PaywallConfiguration: Sendable {
    public let style: PaywallStyle
    public let theme: BioScanTheme
    public let copy: PaywallCopy
    public let catalog: PurchaseCatalog
    public let features: PaywallFeatures
    public let creditAccounting: CreditAccounting
    public let iNatureLayoutStyle: INaturePaywallLayoutStyle
    public let legacyINatureAccent: Color?
    public let cardSelectionAppearance: CardSelectionPaywallAppearance
    public let cardSelectionTheme: CardSelectionPaywallTheme?
    public let purchaseRecovery: PurchaseRecoveryConfiguration?

    public init(
        style: PaywallStyle,
        theme: BioScanTheme = .iNature,
        copy: PaywallCopy = .iNature,
        catalog: PurchaseCatalog,
        features: PaywallFeatures = .iNature,
        creditAccounting: CreditAccounting = .ledger,
        iNatureLayoutStyle: INaturePaywallLayoutStyle = .standard,
        legacyINatureAccent: Color? = nil,
        cardSelectionAppearance: CardSelectionPaywallAppearance = .themed,
        cardSelectionTheme: CardSelectionPaywallTheme? = nil,
        purchaseRecovery: PurchaseRecoveryConfiguration? = .init()
    ) {
        self.style = style
        self.theme = theme
        self.copy = copy
        self.catalog = catalog
        self.features = features
        self.creditAccounting = creditAccounting
        self.iNatureLayoutStyle = iNatureLayoutStyle
        self.legacyINatureAccent = legacyINatureAccent
        self.cardSelectionAppearance = cardSelectionAppearance
        self.cardSelectionTheme = cardSelectionTheme
        self.purchaseRecovery = purchaseRecovery
    }
}

public struct BillingProduct: Identifiable, Equatable, Sendable {
    public let id: String
    public let localizedPrice: String
    public let price: Decimal
    public let currencyCode: String?
    public let localeIdentifier: String?

    public init(
        id: String,
        localizedPrice: String,
        price: Decimal,
        currencyCode: String? = nil,
        localeIdentifier: String? = nil
    ) {
        self.id = id
        self.localizedPrice = localizedPrice
        self.price = price
        self.currencyCode = currencyCode
        self.localeIdentifier = localeIdentifier
    }

    public func localizedUnitPrice(dividingBy divisor: Int) -> String? {
        guard divisor > 0 else { return nil }
        return localizedPrice(multipliedBy: 1 / Decimal(divisor))
    }

    public func localizedPrice(multipliedBy multiplier: Decimal) -> String? {
        guard multiplier > 0 else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        if let localeIdentifier {
            formatter.locale = Locale(identifier: localeIdentifier)
        }
        formatter.currencyCode = currencyCode
        return formatter.string(from: NSDecimalNumber(decimal: price * multiplier))
    }
}

public enum EntitlementState: Equatable, Sendable {
    case unknown
    case standard
    case lifetime
}

public struct PurchaseResult: Equatable, Sendable {
    public let wasCancelled: Bool
    public let transactionID: String?
    public let entitlement: EntitlementState

    public init(
        wasCancelled: Bool,
        transactionID: String? = nil,
        entitlement: EntitlementState
    ) {
        self.wasCancelled = wasCancelled
        self.transactionID = transactionID
        self.entitlement = entitlement
    }
}

public struct CreditBalance: Equatable, Sendable {
    public let free: Int
    public let bonus: Int
    public let paid: Int
    public let hasUnlimitedAccess: Bool

    public init(free: Int, bonus: Int = 0, paid: Int, hasUnlimitedAccess: Bool) {
        self.free = max(0, free)
        self.bonus = max(0, bonus)
        self.paid = max(0, paid)
        self.hasUnlimitedAccess = hasUnlimitedAccess
    }

    public var total: Int {
        guard !hasUnlimitedAccess else { return .max }
        let (freeAndBonus, firstOverflow) = free.addingReportingOverflow(bonus)
        guard !firstOverflow else { return .max }
        let (total, secondOverflow) = freeAndBonus.addingReportingOverflow(paid)
        return secondOverflow ? .max : total
    }
}

public enum BillingOperation: Equatable, Sendable {
    case idle
    case loadingProducts
    case purchasing(productID: String)
    case restoring
    case succeeded
    case cancelled
    case failed(message: String)
}

public struct PaywallNotice: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let message: String

    public init(
        id: UUID = UUID(),
        title: String,
        message: String
    ) {
        self.id = id
        self.title = title
        self.message = message
    }
}

public enum PaywallEvent: Equatable, Sendable {
    case shown(PaywallStyle)
    case productSelected(String)
    case purchaseStarted(String)
    case purchaseSucceeded(String)
    case purchaseCancelled(String)
    case purchaseFailed(String)
    case restoreStarted
    case restoreSucceeded
    case restoreNothingFound
    case restoreFailed
}

public struct PaywallActions {
    public let dismiss: @MainActor () -> Void
    public let track: @MainActor (PaywallEvent) -> Void
    public let syncCreditBalance: @MainActor () -> Void

    public init(
        dismiss: @escaping @MainActor () -> Void,
        track: @escaping @MainActor (PaywallEvent) -> Void = { _ in },
        syncCreditBalance: @escaping @MainActor () -> Void = {}
    ) {
        self.dismiss = dismiss
        self.track = track
        self.syncCreditBalance = syncCreditBalance
    }
}
