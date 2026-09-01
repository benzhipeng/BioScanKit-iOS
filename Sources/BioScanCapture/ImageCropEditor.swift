import BioScanDesign
import SwiftUI
import UIKit

public struct ImageCropEditor: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var panOffset: CGSize = .zero
    @State private var panStart: CGSize = .zero
    @State private var zoom: CGFloat = 1
    @State private var zoomStart: CGFloat = 1
    @State private var didInitialize = false
    @State private var isBorderPulsing = false

    private let image: UIImage
    private let configuration: CropEditorConfiguration
    private let confirmTrigger: Binding<Bool>?
    private let onCancel: () -> Void
    private let confirmFrameChanged: @MainActor (CGRect) -> Void
    private let onConfirm: (UIImage) -> Void

    public init(
        image: UIImage,
        configuration: CropEditorConfiguration = .iNature,
        confirmTrigger: Binding<Bool>? = nil,
        onCancel: @escaping () -> Void,
        confirmFrameChanged: @escaping @MainActor (CGRect) -> Void = { _ in },
        onConfirm: @escaping (UIImage) -> Void
    ) {
        self.image = BioScanImageProcessing.normalized(image)
        self.configuration = configuration
        self.confirmTrigger = confirmTrigger
        self.onCancel = onCancel
        self.confirmFrameChanged = confirmFrameChanged
        self.onConfirm = onConfirm
    }

    public var body: some View {
        GeometryReader { proxy in
            let canvas = canvasFrame(in: proxy)
            let layout = CropGeometry.layout(
                imageSize: image.size,
                canvasFrame: canvas,
                cropScale: configuration.cropScale,
                cropMaximumSize: configuration.cropMaximumSize,
                aspectRatio: configuration.aspectRatio
            )
            let resolvedZoom = max(zoom, layout.minimumZoom)
            let imageRect = CropGeometry.displayedImageRect(
                imageSize: image.size,
                canvasFrame: layout.canvasFrame,
                baseScale: layout.baseScale,
                zoom: resolvedZoom,
                offset: panOffset
            )

            ZStack {
                pageBackground.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .frame(width: imageRect.width, height: imageRect.height)
                    .position(x: imageRect.midX, y: imageRect.midY)
                    .gesture(dragGesture(layout: layout, imageRect: imageRect))
                    .simultaneousGesture(
                        magnificationGesture(layout: layout)
                    )

                CropMaskOverlay(
                    cropRect: layout.cropRect,
                    cornerRadius: configuration.cornerRadius,
                    opacity: configuration.layoutStyle == .iNatureLegacy ? 0.55 : 0.48
                )

                if configuration.layoutStyle == .iNatureLegacy {
                    LegacyCropFrameOverlay(
                        cropRect: layout.cropRect,
                        cornerRadius: configuration.cornerRadius,
                        showsGrid: configuration.showsGrid,
                        accent: configuration.legacyAccent
                    )
                } else {
                    CropFrameOverlay(
                        cropRect: layout.cropRect,
                        cornerRadius: configuration.cornerRadius,
                        showsGrid: configuration.showsGrid,
                        color: configuration.theme.accent,
                        isPulsing: isBorderPulsing
                    )
                }

                if configuration.layoutStyle == .iNatureLegacy {
                    legacyChrome(layout: layout, imageRect: imageRect)
                } else {
                    chrome(layout: layout, imageRect: imageRect)
                }
            }
            .coordinateSpace(name: CropEditorCoordinateSpace.name)
            .onPreferenceChange(CropConfirmFramePreferenceKey.self) {
                confirmFrameChanged($0)
            }
            .onChange(of: confirmTrigger?.wrappedValue ?? false) { shouldConfirm in
                guard shouldConfirm else { return }
                confirm(layout: layout, imageRect: imageRect)
                confirmTrigger?.wrappedValue = false
            }
            .onAppear {
                initializeIfNeeded(layout: layout, imageRect: imageRect)
                guard configuration.animationStyle == .pulse, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    isBorderPulsing = true
                }
            }
            .onChange(of: proxy.size) { _ in
                constrainTransform(layout: layout)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(configuration.hidesStatusBar)
    }

    private func canvasFrame(in proxy: GeometryProxy) -> CGRect {
        let isLegacy = configuration.layoutStyle == .iNatureLegacy
        let topHeight: CGFloat = isLegacy ? 64 : 118
        let bottomHeight: CGFloat = isLegacy
            ? 198
            : (configuration.showsPreview ? 190 : 132)
        return CGRect(
            x: 0,
            y: proxy.safeAreaInsets.top + topHeight,
            width: proxy.size.width,
            height: max(
                proxy.size.height
                    - proxy.safeAreaInsets.top
                    - proxy.safeAreaInsets.bottom
                    - topHeight
                    - bottomHeight,
                120
            )
        )
    }

    private var pageBackground: Color {
        guard configuration.layoutStyle == .iNatureLegacy else {
            return .black
        }
        return colorScheme == .dark
            ? .black
            : Color(red: 0.10, green: 0.12, blue: 0.14)
    }

    private func dragGesture(
        layout: CropLayout,
        imageRect: CGRect
    ) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(
                    width: panStart.width + value.translation.width,
                    height: panStart.height + value.translation.height
                )
                let proposedRect = CropGeometry.displayedImageRect(
                    imageSize: image.size,
                    canvasFrame: layout.canvasFrame,
                    baseScale: layout.baseScale,
                    zoom: max(zoom, layout.minimumZoom),
                    offset: proposed
                )
                panOffset = CropGeometry.clampedOffset(
                    proposed,
                    imageRect: proposedRect,
                    cropRect: layout.cropRect
                )
            }
            .onEnded { _ in
                panStart = panOffset
            }
    }

    private func magnificationGesture(
        layout: CropLayout
    ) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = max(zoomStart * value, layout.minimumZoom)
                constrainTransform(layout: layout)
            }
            .onEnded { _ in
                zoom = max(zoom, layout.minimumZoom)
                zoomStart = zoom
                panStart = panOffset
            }
    }

    private func chrome(
        layout: CropLayout,
        imageRect: CGRect
    ) -> some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.42), in: Circle())
                }
                .foregroundStyle(.white)
                .accessibilityLabel("Close crop editor")

                Spacer()

                if configuration.allowsReset {
                    Button("Reset") {
                        reset(layout: layout)
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(.black.opacity(0.42), in: Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Label(configuration.guidanceText, systemImage: "scope")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(.black.opacity(0.42), in: Capsule())

            Spacer()

            bottomPanel(layout: layout, imageRect: imageRect)
        }
    }

    private func legacyChrome(
        layout: CropLayout,
        imageRect: CGRect
    ) -> some View {
        ZStack {
            VStack(spacing: 12) {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(
                                .black.opacity(colorScheme == .dark ? 0.45 : 0.38),
                                in: Circle()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close crop editor")

                    Spacer()
                    Color.clear.frame(width: 1, height: 1)
                    Spacer()
                    Color.clear.frame(width: 42, height: 42)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(configuration.legacyAccent.opacity(0.18))
                        Image(systemName: "scope")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(configuration.legacyAccent.opacity(0.95))
                    }
                    .frame(width: 28, height: 28)

                    Text(configuration.guidanceText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(maxWidth: 300)
                .background(
                    Color.white.opacity(colorScheme == .dark ? 0.08 : 0.10),
                    in: .rect(cornerRadius: 14)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            configuration.legacyAccent.opacity(
                                colorScheme == .dark ? 0.42 : 0.34
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.24 : 0.12),
                    radius: 12,
                    x: 0,
                    y: 6
                )

                Spacer()
            }

            legacyBottomPanel(layout: layout, imageRect: imageRect)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func legacyBottomPanel(
        layout: CropLayout,
        imageRect: CGRect
    ) -> some View {
        VStack(spacing: 10) {
            HStack {
                Spacer()
                Group {
                    if let preview = croppedImage(layout: layout, imageRect: imageRect) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color.black.opacity(0.25)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                }
                .accessibilityHidden(true)
            }

            HStack(spacing: 12) {
                Button("Reset") {
                    reset(layout: layout)
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Color.white.opacity(colorScheme == .dark ? 0.16 : 0.20),
                    in: .rect(cornerRadius: 12)
                )

                Button {
                    confirm(layout: layout, imageRect: imageRect)
                } label: {
                    Text(configuration.confirmTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            configuration.legacyAccent,
                            in: .rect(cornerRadius: 12)
                        )
                }
                .background {
                    GeometryReader { reader in
                        Color.clear.preference(
                            key: CropConfirmFramePreferenceKey.self,
                            value: reader.frame(in: .global)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
        .padding(.top, 12)
        .background(
            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        .black.opacity(0),
                        .black.opacity(0.55),
                        .black.opacity(0.78)
                    ]
                    : [
                        .black.opacity(0),
                        .black.opacity(0.40),
                        .black.opacity(0.62)
                    ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func bottomPanel(
        layout: CropLayout,
        imageRect: CGRect
    ) -> some View {
        HStack(spacing: 14) {
            if configuration.showsPreview,
               let preview = croppedImage(layout: layout, imageRect: imageRect) {
                Image(uiImage: preview)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    }
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Crop preview")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                Text("Keep the subject clear and centered.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 4)

            Button {
                confirm(layout: layout, imageRect: imageRect)
            } label: {
                Label(configuration.confirmTitle, systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .background(
                        configuration.theme.accent,
                        in: .rect(cornerRadius: configuration.theme.buttonCornerRadius)
                    )
            }
            .background {
                GeometryReader { reader in
                    Color.clear.preference(
                        key: CropConfirmFramePreferenceKey.self,
                        value: reader.frame(in: .global)
                    )
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.72), .black.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func initializeIfNeeded(layout: CropLayout, imageRect: CGRect) {
        guard !didInitialize else { return }
        zoom = layout.minimumZoom
        zoomStart = layout.minimumZoom
        panOffset = CropGeometry.clampedOffset(
            .zero,
            imageRect: imageRect,
            cropRect: layout.cropRect
        )
        panStart = panOffset
        didInitialize = true
    }

    private func reset(layout: CropLayout) {
        if configuration.layoutStyle == .iNatureLegacy {
            zoom = layout.minimumZoom
            zoomStart = layout.minimumZoom
            panOffset = .zero
            panStart = .zero
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            zoom = layout.minimumZoom
            zoomStart = layout.minimumZoom
            panOffset = .zero
            panStart = .zero
        }
    }

    private func constrainTransform(layout: CropLayout) {
        let resolvedZoom = max(zoom, layout.minimumZoom)
        zoom = resolvedZoom
        let imageRect = CropGeometry.displayedImageRect(
            imageSize: image.size,
            canvasFrame: layout.canvasFrame,
            baseScale: layout.baseScale,
            zoom: resolvedZoom,
            offset: panOffset
        )
        panOffset = CropGeometry.clampedOffset(
            panOffset,
            imageRect: imageRect,
            cropRect: layout.cropRect
        )
    }

    private func croppedImage(
        layout: CropLayout,
        imageRect: CGRect
    ) -> UIImage? {
        let normalizedRect = CropGeometry.normalizedCropRect(
            cropRect: layout.cropRect,
            imageRect: imageRect
        )
        return BioScanImageProcessing.crop(image, normalizedRect: normalizedRect)
    }

    private func confirm(layout: CropLayout, imageRect: CGRect) {
        guard let output = croppedImage(layout: layout, imageRect: imageRect) else { return }
        onConfirm(output)
    }
}

private enum CropEditorCoordinateSpace {
    static let name = "BioScanKit.ImageCropEditor"
}

private struct CropConfirmFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.isEmpty {
            value = next
        }
    }
}

private struct CropMaskOverlay: View {
    let cropRect: CGRect
    let cornerRadius: CGFloat
    let opacity: Double

    var body: some View {
        Rectangle()
            .fill(.black.opacity(opacity))
            .mask {
                Rectangle()
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .frame(width: cropRect.width, height: cropRect.height)
                            .position(x: cropRect.midX, y: cropRect.midY)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
            }
            .allowsHitTesting(false)
    }
}

private struct LegacyCropFrameOverlay: View {
    let cropRect: CGRect
    let cornerRadius: CGFloat
    let showsGrid: Bool
    let accent: Color

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(accent, lineWidth: 2)
            .frame(width: cropRect.width, height: cropRect.height)
            .position(x: cropRect.midX, y: cropRect.midY)
            .overlay {
                if showsGrid {
                    CropGrid()
                        .stroke(.white.opacity(0.24), lineWidth: 1)
                        .frame(
                            width: max(cropRect.width - 8, 0),
                            height: max(cropRect.height - 8, 0)
                        )
                        .position(x: cropRect.midX, y: cropRect.midY)
                }
            }
            .allowsHitTesting(false)
    }
}

private struct CropFrameOverlay: View {
    let cropRect: CGRect
    let cornerRadius: CGFloat
    let showsGrid: Bool
    let color: Color
    let isPulsing: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(color, lineWidth: isPulsing ? 3 : 2)
            .shadow(color: color.opacity(isPulsing ? 0.55 : 0.2), radius: isPulsing ? 10 : 4)
            .frame(width: cropRect.width, height: cropRect.height)
            .position(x: cropRect.midX, y: cropRect.midY)
            .overlay {
                if showsGrid {
                    CropGrid()
                        .stroke(.white.opacity(0.34), lineWidth: 0.7)
                        .frame(
                            width: max(cropRect.width - 8, 0),
                            height: max(cropRect.height - 8, 0)
                        )
                        .position(x: cropRect.midX, y: cropRect.midY)
                }
            }
            .allowsHitTesting(false)
    }
}

private struct CropGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for fraction in [CGFloat(1) / 3, CGFloat(2) / 3] {
            path.move(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * fraction, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * fraction))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * fraction))
        }
        return path
    }
}
