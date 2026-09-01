import SwiftUI

struct INaturePaywallView<Hero: View>: View {
    @ObservedObject var store: PaywallStore

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
        Group {
            switch configuration.iNatureLayoutStyle {
            case .standard:
                StandardINaturePaywallView(
                    store: store,
                    configuration: configuration,
                    hero: hero
                )
            case .legacyINature, .legacyNatureEar:
                LegacyINaturePaywallView(
                    configuration: configuration,
                    store: store,
                    hero: hero
                )
            }
        }
    }
}

private struct StandardINaturePaywallView<Hero: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var store: PaywallStore

    let configuration: PaywallConfiguration
    let hero: Hero

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = max(proxy.safeAreaInsets.bottom, 8)

            ZStack(alignment: .bottom) {
                configuration.theme.pageBackground
                    .resolve(for: colorScheme)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: configuration.theme.sectionSpacing) {
                        PaywallTopBar(
                            store: store,
                            theme: configuration.theme,
                            restoreTitle: configuration.copy.restoreTitle
                        )
                        heroSection
                        StoreStatusBanner(store: store, configuration: configuration)
                        lifetimeSection
                        creditSection

                        if configuration.features.showsAssurance {
                            assuranceSection
                        }
                    }
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, configuration.theme.horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, bottomInset + 96)
                }

                PaywallPrimaryButton(store: store, configuration: configuration)
                    .frame(maxWidth: 760)
                    .padding(.horizontal, configuration.theme.horizontalPadding)
                    .padding(.top, 10)
                    .padding(.bottom, bottomInset)
                    .background(
                        configuration.theme.pageBackground
                            .resolve(for: colorScheme)
                            .opacity(0.97)
                            .ignoresSafeArea(edges: .bottom)
                    )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            hero

            Text(configuration.copy.title)
                .font(.largeTitle.weight(.black))
                .foregroundStyle(configuration.theme.primaryText.resolve(for: colorScheme))

            Text(configuration.copy.subtitle)
                .font(.body.weight(.medium))
                .foregroundStyle(configuration.theme.secondaryText.resolve(for: colorScheme))

            if configuration.features.showsCreditBalance {
                CreditBalanceBadge(
                    balance: store.creditBalance,
                    theme: configuration.theme
                )
            }
        }
    }

    private var lifetimeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(configuration.copy.lifetimeSectionTitle)

            if let product = configuration.catalog.products.first(where: {
                if case .lifetime = $0.kind { return true }
                return false
            }) {
                Button {
                    store.select(product.id)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 54, height: 54)
                            .background(configuration.theme.accent.gradient, in: Circle())
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(product.title)
                                    .font(.title3.weight(.black))
                                if let badge = product.badge {
                                    Text(badge.uppercased())
                                        .font(.caption2.weight(.black))
                                        .foregroundStyle(configuration.theme.accent)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 4)
                                        .background(
                                            configuration.theme.accent.opacity(0.10),
                                            in: Capsule()
                                        )
                                }
                            }

                            Text(product.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            priceLine(for: product)
                        }

                        Spacer()
                        selectionIndicator(isSelected: store.selectedProductID == product.id)
                    }
                    .padding(16)
                    .background(
                        configuration.theme.cardBackground.resolve(for: colorScheme),
                        in: .rect(cornerRadius: configuration.theme.cardCornerRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: configuration.theme.cardCornerRadius)
                            .stroke(
                                store.selectedProductID == product.id
                                    ? configuration.theme.accent
                                    : configuration.theme.border.resolve(for: colorScheme),
                                lineWidth: store.selectedProductID == product.id ? 2 : 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(
                    store.selectedProductID == product.id ? .isSelected : []
                )
            }
        }
    }

    private var creditSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(configuration.copy.creditSectionTitle)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                ForEach(creditProducts) { product in
                    creditCard(product)
                }
            }
        }
    }

    private var creditProducts: [PaywallProduct] {
        configuration.catalog.products.filter {
            if case .credits = $0.kind { return true }
            return false
        }
    }

    private func creditCard(_ product: PaywallProduct) -> some View {
        Button {
            store.select(product.id)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(configuration.theme.accent)
                        .accessibilityHidden(true)
                    Spacer()
                    selectionIndicator(isSelected: store.selectedProductID == product.id)
                }

                Text(product.title)
                    .font(.headline)
                Text(product.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                priceLine(for: product)

                if case .credits(let count) = product.kind,
                   let unitPrice = store.productDetails(for: product.id)?
                    .localizedUnitPrice(dividingBy: count) {
                    Text("\(unitPrice) each")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 134, alignment: .leading)
            .padding(14)
            .background(
                configuration.theme.cardBackground.resolve(for: colorScheme),
                in: .rect(cornerRadius: configuration.theme.cardCornerRadius)
            )
            .overlay {
                RoundedRectangle(cornerRadius: configuration.theme.cardCornerRadius)
                    .stroke(
                        store.selectedProductID == product.id
                            ? configuration.theme.accent
                            : configuration.theme.border.resolve(for: colorScheme),
                        lineWidth: store.selectedProductID == product.id ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(
            store.selectedProductID == product.id ? .isSelected : []
        )
    }

    private var assuranceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(configuration.copy.assuranceTitle)

            ForEach(configuration.copy.assuranceItems, id: \.self) { item in
                Label(item, systemImage: "checkmark.shield.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(configuration.theme.secondaryText.resolve(for: colorScheme))
            }
        }
        .padding(16)
        .background(
            configuration.theme.elevatedCardBackground.resolve(for: colorScheme),
            in: .rect(cornerRadius: configuration.theme.cardCornerRadius)
        )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.black))
            .tracking(0.9)
            .foregroundStyle(configuration.theme.secondaryText.resolve(for: colorScheme))
    }

    private func priceLine(for product: PaywallProduct) -> some View {
        HStack(spacing: 7) {
            Text(store.productDetails(for: product.id)?.localizedPrice ?? "—")
                .font(.headline.weight(.black))
                .foregroundStyle(configuration.theme.primaryText.resolve(for: colorScheme))

            if configuration.features.showsOriginalPrice,
               case .lifetime = product.kind,
               let original = store.localizedOriginalPrice(for: product.id) {
                Text(original)
                    .font(.caption)
                    .strikethrough()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(
                isSelected ? configuration.theme.accent : Color.secondary
            )
            .accessibilityHidden(true)
    }
}
