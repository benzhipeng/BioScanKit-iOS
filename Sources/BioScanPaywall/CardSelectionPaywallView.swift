import SwiftUI

/// The selectable-card paywall preserves the original Rock purchase-page layout.
/// Apps provide only theme, copy, products, billing actions, and optional hero content.
struct CardSelectionPaywallView<Hero: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: PaywallStore
    @State private var ctaShimmerOffset: CGFloat = -0.95

    let configuration: PaywallConfiguration
    let hero: Hero

    init(
        configuration: PaywallConfiguration,
        store: PaywallStore,
        hero: Hero
    ) {
        self.configuration = configuration
        self.store = store
        self.hero = hero
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header

                VStack(spacing: 12) {
                    storeStatus
                    productCards
                    actionArea
                }
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .background(background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: store.operation) { operation in
            guard operation == .succeeded else { return }
            store.dismiss()
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: backgroundGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(glowStrong)
                .frame(width: 260, height: 260)
                .offset(x: 128, y: -220)

            Circle()
                .fill(glowSoft)
                .frame(width: 208, height: 208)
                .offset(x: -144, y: -68)
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button(action: store.dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(closeIcon)
                        .frame(width: 32, height: 32)
                        .background(
                            closeBackground,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(BioScanPaywallL10n.string("Close"))
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            VStack(spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    hero
                        .frame(
                            width: cardTheme.heroSize.width,
                            height: cardTheme.heroSize.height
                        )
                        .background(
                            mascotCard,
                            in: .rect(cornerRadius: cardTheme.heroCornerRadius)
                        )
                        .clipShape(.rect(cornerRadius: cardTheme.heroCornerRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: cardTheme.heroCornerRadius)
                                .stroke(
                                    mascotCardStroke,
                                    lineWidth: 1
                                )
                        }
                        .shadow(
                            color: shadowColor.opacity(0.14),
                            radius: 20,
                            y: 8
                        )

                    Image(systemName: "sparkle")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(accentText)
                        .offset(x: 8, y: -6)
                        .accessibilityHidden(true)
                }
                .padding(.top, 2)

                Text(BioScanPaywallL10n.string(configuration.copy.title))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(headerTitle)
                    .multilineTextAlignment(.center)

                balanceBadge
                    .padding(.top, 2)

                Text(BioScanPaywallL10n.string(configuration.copy.subtitle))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(headerSubtitle)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1.5)
                    .padding(.top, 7)
                    .padding(.bottom, 11)
                    .padding(.horizontal, 28)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
        }
    }

    private var balanceBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(
                    store.creditBalance.hasUnlimitedAccess
                        ? statusActive
                        : counterDot
                )
                .frame(width: 7, height: 7)

            Text(balanceText)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(counterText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(counterBackground, in: Capsule())
        .overlay {
            Capsule()
                .stroke(counterBorder, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var storeStatus: some View {
        switch store.operation {
        case .failed, .loadingProducts, .restoring:
            StoreStatusBanner(store: store, configuration: configuration)
        default:
            EmptyView()
        }
    }

    private var productCards: some View {
        VStack(spacing: 12) {
            ForEach(configuration.catalog.products) { product in
                productCard(product)
            }
        }
    }

    private func productCard(_ product: PaywallProduct) -> some View {
        let isSelected = store.selectedProductID == product.id
        let isLifetime = product.kind == .lifetime
        let isAvailable = store.productDetails(for: product.id) != nil

        return Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                store.select(product.id)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                selectionRing(isSelected: isSelected, isLifetime: isLifetime)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 8) {
                    Text(BioScanPaywallL10n.string(product.title))
                        .font(
                            .system(
                                size: isLifetime ? 20 : 17,
                                weight: .black,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(primaryText(isLifetime: isLifetime))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(BioScanPaywallL10n.string(product.subtitle))
                        .font(
                            .system(
                                size: isLifetime ? 14 : 13,
                                weight: .bold,
                                design: .default
                            )
                        )
                        .foregroundStyle(secondaryText(isLifetime: isLifetime))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 6) {
                    if configuration.features.showsOriginalPrice,
                       case .lifetime = product.kind,
                       let originalPriceText = store.localizedOriginalPrice(for: product.id) {
                        Text(originalPriceText)
                            .font(
                                .system(
                                    size: isLifetime ? 14 : 11,
                                    weight: .bold,
                                    design: .rounded
                                )
                            )
                            .foregroundStyle(secondaryText(isLifetime: isLifetime))
                            .strikethrough()
                    }

                    Text(store.productDetails(for: product.id)?.localizedPrice ?? "—")
                        .font(
                            .system(
                                size: isLifetime ? 26 : 22,
                                weight: .black,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(primaryText(isLifetime: isLifetime))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    if case .credits(let count) = product.kind,
                       let unitPrice = store.productDetails(for: product.id)?
                        .localizedUnitPrice(dividingBy: count) {
                        Text(unitPrice + BioScanPaywallL10n.string(product.unitSuffix ?? " each"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(tertiaryText(isLifetime: isLifetime))
                    }

                    if let footerText = product.footerText {
                        Text(BioScanPaywallL10n.string(footerText))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(tertiaryText(isLifetime: isLifetime))
                    }
                }
                .padding(.top, isLifetime ? 12 : 0)
                .frame(minWidth: isLifetime ? 118 : 102, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, isLifetime ? 17 : 15)
            .frame(maxWidth: .infinity)
            .background(cardBackground(isLifetime: isLifetime, isSelected: isSelected))
            .clipShape(.rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        cardBorder(isLifetime: isLifetime, isSelected: isSelected),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .overlay(alignment: .topTrailing) {
                if let badge = product.badge {
                    Text(BioScanPaywallL10n.string(badge).uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            isLifetime ? heroTextPrimary : accentText
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            isLifetime
                                ? heroGlass
                                : selectedFill,
                            in: Capsule()
                        )
                        .padding(.top, 10)
                        .padding(.trailing, 12)
                }
            }
            .shadow(
                color: shadowColor.opacity(
                    isSelected ? 0.22 : (isLifetime ? 0.14 : 0.06)
                ),
                radius: isLifetime ? 18 : 12,
                y: 6
            )
            .opacity(isAvailable ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(store.isBusy || !isAvailable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var actionArea: some View {
        VStack(spacing: 14) {
            purchaseButton

            Button(BioScanPaywallL10n.string(configuration.copy.restoreTitle)) {
                Task {
                    await store.restorePurchases()
                }
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(
                restoreText
            )
            .underline()
            .buttonStyle(.plain)
            .disabled(store.isBusy)
        }
    }

    private var purchaseButton: some View {
        Button {
            if store.entitlement == .lifetime {
                store.dismiss()
            } else {
                Task {
                    await store.purchaseSelectedProduct()
                }
            }
        } label: {
            HStack(spacing: 10) {
                if store.isBusy {
                    ProgressView()
                        .tint(.white)
                }

                Text(BioScanPaywallL10n.string(purchaseButtonTitle))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: ctaGradientColors,
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: .rect(cornerRadius: 18)
            )
            .overlay {
                GeometryReader { proxy in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color.white.opacity(0.04),
                                    Color.white.opacity(0.26),
                                    Color.white.opacity(0.04),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(proxy.size.width, 1) * 0.42,
                            height: max(proxy.size.height, 1) * 1.9
                        )
                        .blur(radius: 10)
                        .rotationEffect(.degrees(-18))
                        .offset(x: max(proxy.size.width, 1) * ctaShimmerOffset)
                        .blendMode(.screen)
                }
                .clipShape(.rect(cornerRadius: 18))
                .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(ctaStroke, lineWidth: 1)
            }
            .shadow(color: ctaShadow.opacity(0.30), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(purchaseButtonDisabled)
        .opacity(purchaseButtonDisabled ? 0.55 : 1)
        .onAppear {
            guard ctaShimmerOffset == -0.95 else { return }
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: false)) {
                ctaShimmerOffset = 0.95
            }
        }
    }

    private var purchaseButtonTitle: String {
        guard let selectedProduct = store.selectedProduct else {
            return configuration.copy.purchaseTitle
        }
        let actionTitle = selectedProduct.purchaseActionTitle
        guard let price = store.productDetails(for: selectedProduct.id)?.localizedPrice else {
            return actionTitle
        }
        return actionTitle + configuration.copy.purchasePriceSeparator + price
    }

    private var purchaseButtonDisabled: Bool {
        if store.entitlement == .lifetime { return false }
        guard let selectedProductID = store.selectedProductID else { return true }
        return store.isBusy || store.productDetails(for: selectedProductID) == nil
    }

    private var balanceText: String {
        store.creditBalance.hasUnlimitedAccess
            ? configuration.copy.activeLifetimeTitle
            : "\(store.creditBalance.total) scans left"
    }

    private func selectionRing(
        isSelected: Bool,
        isLifetime: Bool
    ) -> some View {
        Circle()
            .stroke(
                isSelected
                    ? (isLifetime ? lifetimeHighlight : selectedBorder)
                    : (isLifetime
                        ? heroGlassStroke
                        : cardBorderColor),
                lineWidth: 2
            )
            .frame(width: 22, height: 22)
            .overlay {
                Circle()
                    .fill(isLifetime ? lifetimeHighlight : selectedBorder)
                    .frame(width: 10, height: 10)
                    .opacity(isSelected ? 1 : 0)
            }
    }

    private func primaryText(isLifetime: Bool) -> Color {
        isLifetime
            ? heroTextPrimary
            : cardTitle
    }

    private func secondaryText(isLifetime: Bool) -> Color {
        isLifetime
            ? heroTextSecondary
            : cardSubtitle
    }

    private func tertiaryText(isLifetime: Bool) -> Color {
        isLifetime ? heroTextSecondary : accentText
    }

    private func cardBackground(
        isLifetime: Bool,
        isSelected: Bool
    ) -> AnyShapeStyle {
        if isLifetime {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        lifetimeStart,
                        lifetimeMid,
                        lifetimeEnd
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        guard isSelected else {
            return AnyShapeStyle(cardBackgroundColor)
        }

        return AnyShapeStyle(
            LinearGradient(
                colors: [selectedFill, cardBackgroundColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func cardBorder(
        isLifetime: Bool,
        isSelected: Bool
    ) -> Color {
        if isLifetime {
            return isSelected ? lifetimeHighlight : heroGlassStroke
        }
        return isSelected ? selectedBorder : cardBorderColor
    }

    private var usesLegacyRockAppearance: Bool {
        configuration.cardSelectionAppearance == .legacyRock
    }

    private var cardTheme: CardSelectionPaywallTheme {
        if let theme = configuration.cardSelectionTheme {
            return theme
        }
        if usesLegacyRockAppearance {
            return .legacyRock
        }
        return .derived(from: configuration.theme)
    }

    private var backgroundGradientColors: [Color] {
        cardTheme.backgroundGradient.map { $0.resolve(for: colorScheme) }
    }

    private var glowStrong: Color {
        cardTheme.glowStrong.resolve(for: colorScheme)
    }

    private var glowSoft: Color {
        cardTheme.glowSoft.resolve(for: colorScheme)
    }

    private var closeBackground: Color {
        cardTheme.closeBackground.resolve(for: colorScheme)
    }

    private var closeIcon: Color {
        cardTheme.closeIcon.resolve(for: colorScheme)
    }

    private var headerTitle: Color {
        cardTheme.headerTitle.resolve(for: colorScheme)
    }

    private var headerSubtitle: Color {
        cardTheme.headerSubtitle.resolve(for: colorScheme)
    }

    private var counterBackground: Color {
        cardTheme.counterBackground.resolve(for: colorScheme)
    }

    private var counterBorder: Color {
        cardTheme.counterBorder.resolve(for: colorScheme)
    }

    private var counterText: Color {
        cardTheme.counterText.resolve(for: colorScheme)
    }

    private var counterDot: Color {
        cardTheme.counterDot.resolve(for: colorScheme)
    }

    private var statusActive: Color {
        cardTheme.statusActive.resolve(for: colorScheme)
    }

    private var mascotCard: Color {
        cardTheme.mascotCard.resolve(for: colorScheme)
    }

    private var mascotCardStroke: Color {
        cardTheme.mascotCardStroke.resolve(for: colorScheme)
    }

    private var heroTextPrimary: Color {
        cardTheme.heroTextPrimary.resolve(for: colorScheme)
    }

    private var heroTextSecondary: Color {
        cardTheme.heroTextSecondary.resolve(for: colorScheme)
    }

    private var heroGlass: Color {
        cardTheme.heroGlass.resolve(for: colorScheme)
    }

    private var heroGlassStroke: Color {
        cardTheme.heroGlassStroke.resolve(for: colorScheme)
    }

    private var cardBackgroundColor: Color {
        cardTheme.cardBackground.resolve(for: colorScheme)
    }

    private var cardBorderColor: Color {
        cardTheme.cardBorder.resolve(for: colorScheme)
    }

    private var cardTitle: Color {
        cardTheme.cardTitle.resolve(for: colorScheme)
    }

    private var cardSubtitle: Color {
        cardTheme.cardSubtitle.resolve(for: colorScheme)
    }

    private var selectedFill: Color {
        cardTheme.selectedFill.resolve(for: colorScheme)
    }

    private var selectedBorder: Color {
        cardTheme.selectedBorder.resolve(for: colorScheme)
    }

    private var accentText: Color {
        cardTheme.accentText.resolve(for: colorScheme)
    }

    private var lifetimeStart: Color {
        cardTheme.lifetimeStart.resolve(for: colorScheme)
    }

    private var lifetimeMid: Color {
        cardTheme.lifetimeMid.resolve(for: colorScheme)
    }

    private var lifetimeEnd: Color {
        cardTheme.lifetimeEnd.resolve(for: colorScheme)
    }

    private var lifetimeHighlight: Color {
        cardTheme.lifetimeHighlight.resolve(for: colorScheme)
    }

    private var ctaGradientColors: [Color] {
        cardTheme.ctaGradient.map { $0.resolve(for: colorScheme) }
    }

    private var ctaStroke: Color {
        cardTheme.ctaStroke.resolve(for: colorScheme)
    }

    private var ctaShadow: Color {
        cardTheme.ctaShadow.resolve(for: colorScheme)
    }

    private var shadowColor: Color {
        cardTheme.shadow.resolve(for: colorScheme)
    }

    private var restoreText: Color {
        cardTheme.restoreText.resolve(for: colorScheme)
    }
}
