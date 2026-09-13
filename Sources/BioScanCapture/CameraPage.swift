import SwiftUI
import UIKit

public struct CameraPageActions {
    public let close: @MainActor () -> Void
    public let showHelp: (@MainActor () -> Void)?
    public let choosePhoto: @MainActor () -> Void
    public let capture: @MainActor () -> Void
    public let focus: (@MainActor (CGPoint) -> Void)?
    public let focusFrameChanged: @MainActor (CGRect) -> Void
    public let cropFrameChanged: @MainActor (CGRect) -> Void
    public let captureFrameChanged: @MainActor (CGRect) -> Void

    public init(
        close: @escaping @MainActor () -> Void,
        showHelp: (@MainActor () -> Void)? = nil,
        choosePhoto: @escaping @MainActor () -> Void,
        capture: @escaping @MainActor () -> Void,
        focus: (@MainActor (CGPoint) -> Void)? = nil,
        focusFrameChanged: @escaping @MainActor (CGRect) -> Void = { _ in },
        cropFrameChanged: @escaping @MainActor (CGRect) -> Void = { _ in },
        captureFrameChanged: @escaping @MainActor (CGRect) -> Void = { _ in }
    ) {
        self.close = close
        self.showHelp = showHelp
        self.choosePhoto = choosePhoto
        self.capture = capture
        self.focus = focus
        self.focusFrameChanged = focusFrameChanged
        self.cropFrameChanged = cropFrameChanged
        self.captureFrameChanged = captureFrameChanged
    }
}

public struct CameraPage<Preview: View, ExtraOverlay: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var flashEnabled: Bool
    @Binding private var zoomFactor: CGFloat
    @State private var zoomAtGestureStart: CGFloat
    @State private var isZooming = false
    @State private var previewFrame: CGRect = .zero
    @State private var focusFrame: CGRect = .zero
    @State private var isFinderAnimating = false

    private let configuration: CameraScreenConfiguration
    private let actions: CameraPageActions
    private let showsCloseButton: Bool
    private let isProcessing: Bool
    private let isCaptureEnabled: Bool
    private let allowsCameraGestures: Bool
    private let galleryPreviewImage: UIImage?
    private let finderImage: UIImage?
    private let preview: Preview
    private let extraOverlay: ExtraOverlay

    public init(
        configuration: CameraScreenConfiguration = .iNature,
        flashEnabled: Binding<Bool>,
        zoomFactor: Binding<CGFloat>,
        showsCloseButton: Bool = true,
        isProcessing: Bool = false,
        isCaptureEnabled: Bool = true,
        allowsCameraGestures: Bool = true,
        galleryPreviewImage: UIImage? = nil,
        finderImage: UIImage? = nil,
        actions: CameraPageActions,
        @ViewBuilder preview: () -> Preview,
        @ViewBuilder extraOverlay: () -> ExtraOverlay
    ) {
        self.configuration = configuration
        _flashEnabled = flashEnabled
        _zoomFactor = zoomFactor
        _zoomAtGestureStart = State(initialValue: zoomFactor.wrappedValue)
        self.showsCloseButton = showsCloseButton
        self.isProcessing = isProcessing
        self.isCaptureEnabled = isCaptureEnabled
        self.allowsCameraGestures = allowsCameraGestures
        self.galleryPreviewImage = galleryPreviewImage
        self.finderImage = finderImage
        self.actions = actions
        self.preview = preview()
        self.extraOverlay = extraOverlay()
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .background {
                        GeometryReader { reader in
                            Color.clear.preference(
                                key: CameraPreviewFramePreferenceKey.self,
                                value: reader.frame(in: .named(CameraPageCoordinateSpace.name))
                            )
                        }
                    }
                    .simultaneousGesture(zoomGesture)
                    .simultaneousGesture(focusGesture)

                vignette

                if configuration.layoutStyle == .iNatureLegacy {
                    legacyLayout(proxy: proxy)
                } else {
                    adaptiveLayout(proxy: proxy)
                }

                extraOverlay
            }
            .background(.black)
            .coordinateSpace(name: CameraPageCoordinateSpace.name)
            .onPreferenceChange(CameraPreviewFramePreferenceKey.self) {
                previewFrame = $0
                publishCropFrame()
            }
            .onPreferenceChange(CameraFocusFramePreferenceKey.self) {
                focusFrame = $0
                actions.focusFrameChanged($0)
                publishCropFrame()
            }
            .onPreferenceChange(CameraCaptureFramePreferenceKey.self) {
                actions.captureFrameChanged($0)
            }
            .ignoresSafeArea(
                .container,
                edges: isIPadLandscape(proxy) ? .horizontal : []
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard configuration.finderStyle == .scanner, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                isFinderAnimating = true
            }
        }
        .onChange(of: zoomFactor) { value in
            guard !isZooming else { return }
            zoomAtGestureStart = value
        }
    }

    private var vignette: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    .black.opacity(configuration.layoutStyle == .iNatureLegacy ? 0.45 : 0.50),
                    .black.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: configuration.layoutStyle == .iNatureLegacy ? 170 : 180)

            Spacer(minLength: 0)

            LinearGradient(
                colors: [
                    .black.opacity(0.02),
                    .black.opacity(configuration.layoutStyle == .iNatureLegacy ? 0.52 : 0.58)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: configuration.layoutStyle == .iNatureLegacy ? 230 : 240)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if showsCloseButton {
                    circleButton(systemImage: "xmark", action: actions.close)
                        .accessibilityLabel(BioScanCaptureL10n.string(configuration.closeAccessibilityLabel))
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }

                Spacer()

                if let showHelp = actions.showHelp {
                    circleButton(systemImage: "questionmark", action: showHelp)
                        .accessibilityLabel(BioScanCaptureL10n.string(configuration.helpAccessibilityLabel))
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
            }

            if let statusText = configuration.statusText {
                HStack(spacing: 6) {
                    Image(systemName: configuration.statusSystemImage)
                        .font(.system(size: 11, weight: .bold))
                    Text(BioScanCaptureL10n.string(statusText))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                    .foregroundStyle(configuration.statusForegroundColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.45), in: Capsule())
            }
        }
    }

    private func legacyLayout(proxy: GeometryProxy) -> some View {
        VStack {
            topBar
            Spacer()
            instructionPill
            legacyFinder
            Spacer()
            controls
        }
        .frame(maxWidth: contentMaximumWidth(in: proxy))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 18)
    }

    private func adaptiveLayout(proxy: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 16)
            focusContent(availableHeight: proxy.size.height)
            Spacer(minLength: 16)
            controls
        }
        .frame(maxWidth: contentMaximumWidth(in: proxy))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    private func isIPadLandscape(_ proxy: GeometryProxy) -> Bool {
        UIDevice.current.userInterfaceIdiom == .pad
            && proxy.size.width > proxy.size.height
    }

    private func contentMaximumWidth(in proxy: GeometryProxy) -> CGFloat {
        isIPadLandscape(proxy) ? .infinity : 760
    }

    private var instructionPill: some View {
        Text(BioScanCaptureL10n.string(isProcessing ? configuration.processingInstruction : configuration.instruction))
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.45), in: Capsule())
    }

    private var legacyFinder: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, configuration.finderMaximumSize)

            ZStack {
                CameraCornerMarkers(
                    color: configuration.finderColor ?? configuration.theme.accent,
                    lineWidth: 3,
                    rounded: false
                )

                if let finderImage {
                    Image(uiImage: finderImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: max(size - 18, 0), height: max(size - 18, 0))
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: configuration.finderCornerRadius,
                                style: .continuous
                            )
                        )
                }
            }
            .frame(width: size, height: size)
            .background {
                GeometryReader { reader in
                    Color.clear.preference(
                        key: CameraFocusFramePreferenceKey.self,
                        value: reader.frame(in: .named(CameraPageCoordinateSpace.name))
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 320)
        .allowsHitTesting(!isProcessing)
    }

    private func focusContent(availableHeight: CGFloat) -> some View {
        let metrics = CameraPageLayout.metrics(
            availableHeight: availableHeight,
            configuredMaximumFinderSize: configuration.finderMaximumSize
        )

        return VStack(spacing: 12) {
            Text(BioScanCaptureL10n.string(isProcessing ? configuration.processingInstruction : configuration.instruction))
                .font(
                    .system(.subheadline, design: configuration.theme.fontDesign)
                        .weight(.semibold)
                )
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(.black.opacity(0.45), in: Capsule())

            GeometryReader { frameProxy in
                let size = min(
                    min(frameProxy.size.width, frameProxy.size.height),
                    metrics.maximumFinderSize
                )

                cameraFinder(size: size)
                    .scaleEffect(
                        isProcessing
                            ? 0.97
                            : (configuration.finderStyle == .scanner && isFinderAnimating ? 1.03 : 0.98)
                    )
                .background {
                    GeometryReader { reader in
                        Color.clear.preference(
                            key: CameraFocusFramePreferenceKey.self,
                            value: reader.frame(in: .named(CameraPageCoordinateSpace.name))
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: metrics.areaHeight)
        }
        .allowsHitTesting(!isProcessing)
    }

    private var controls: some View {
        HStack {
            if configuration.supportsPhotoLibrary {
                Button(action: actions.choosePhoto) {
                    ZStack {
                        Circle()
                            .fill(.black.opacity(configuration.layoutStyle == .iNatureLegacy ? 0.45 : 0.42))
                            .frame(width: sideControlSize, height: sideControlSize)

                        if let galleryPreviewImage {
                            Image(uiImage: galleryPreviewImage)
                                .resizable()
                                .scaledToFill()
                                .frame(
                                    width: configuration.layoutStyle == .iNatureLegacy ? 34 : sideControlSize,
                                    height: configuration.layoutStyle == .iNatureLegacy ? 34 : sideControlSize
                                )
                                .clipShape(
                                    configuration.layoutStyle == .iNatureLegacy
                                        ? AnyShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        : AnyShape(Circle())
                                )
                        } else {
                            Image(systemName: "photo.on.rectangle")
                                .font(
                                    configuration.layoutStyle == .iNatureLegacy
                                        ? .system(size: 16, weight: .bold)
                                        : .title3.weight(.bold)
                                )
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: sideControlSize, height: sideControlSize)
                    .overlay {
                        if configuration.layoutStyle == .adaptive {
                            Circle().stroke(.white.opacity(0.18), lineWidth: 1)
                        }
                    }
                }
                    .buttonStyle(.plain)
                    .accessibilityLabel(BioScanCaptureL10n.string(configuration.galleryAccessibilityLabel))
                    .disabled(isProcessing)
                    .opacity(
                        configuration.layoutStyle == .iNatureLegacy && isProcessing
                            ? 0.45
                            : 1
                    )
            } else {
                Color.clear.frame(width: sideControlSize, height: sideControlSize)
            }

            Spacer()

            Button(action: actions.capture) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: shutterOuterSize, height: shutterOuterSize)

                    Circle()
                        .fill(isProcessing ? .white.opacity(0.75) : .white)
                        .frame(width: shutterInnerSize, height: shutterInnerSize)

                    if isProcessing {
                        ProgressView()
                            .tint(.black.opacity(0.65))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!isCaptureEnabled || isProcessing)
            .opacity(
                isCaptureEnabled && !isProcessing
                    ? 1
                    : (configuration.layoutStyle == .iNatureLegacy ? 0.7 : 0.55)
            )
            .scaleEffect(
                configuration.layoutStyle == .adaptive && isProcessing ? 0.92 : 1
            )
            .accessibilityLabel(BioScanCaptureL10n.string(configuration.captureAccessibilityLabel))
            .background {
                GeometryReader { reader in
                    Color.clear.preference(
                        key: CameraCaptureFramePreferenceKey.self,
                        value: reader.frame(in: .named(CameraPageCoordinateSpace.name))
                    )
                }
            }

            Spacer()

            if configuration.supportsFlash {
                circleButton(
                    systemImage: flashEnabled ? "bolt.fill" : "bolt.slash.fill"
                ) {
                    flashEnabled.toggle()
                }
                .disabled(isProcessing)
                .opacity(
                    configuration.layoutStyle == .iNatureLegacy && isProcessing
                        ? 0.45
                        : 1
                )
                .accessibilityLabel(
                    flashEnabled
                        ? configuration.flashOnAccessibilityLabel
                        : configuration.flashOffAccessibilityLabel
                )
            } else {
                Color.clear.frame(width: sideControlSize, height: sideControlSize)
            }
        }
        .padding(.horizontal, configuration.layoutStyle == .iNatureLegacy ? 0 : 10)
    }

    private func circleButton(
        systemImage: String,
        action: @escaping @MainActor () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(
                    configuration.layoutStyle == .iNatureLegacy
                        ? .system(size: 16, weight: .bold)
                        : .title3.weight(.bold)
                )
                .foregroundStyle(.white)
                .frame(width: sideControlSize, height: sideControlSize)
                .background(
                    .black.opacity(configuration.layoutStyle == .iNatureLegacy ? 0.45 : 0.42),
                    in: Circle()
                )
                .overlay {
                    if configuration.layoutStyle == .adaptive {
                        Circle().stroke(.white.opacity(0.14), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var sideControlSize: CGFloat {
        configuration.layoutStyle == .iNatureLegacy ? 42 : 54
    }

    private var shutterOuterSize: CGFloat {
        configuration.layoutStyle == .iNatureLegacy ? 84 : 88
    }

    private var shutterInnerSize: CGFloat {
        configuration.layoutStyle == .iNatureLegacy ? 64 : 68
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard configuration.supportsPinchToZoom,
                      allowsCameraGestures,
                      !isProcessing else { return }
                isZooming = true
                zoomFactor = min(
                    max(zoomAtGestureStart * value, 1),
                    configuration.maximumZoomFactor
                )
            }
            .onEnded { _ in
                isZooming = false
                zoomAtGestureStart = zoomFactor
            }
    }

    private var focusGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard configuration.supportsTapToFocus,
                      allowsCameraGestures,
                      !isProcessing else { return }
                actions.focus?(value.location)
            }
    }

    @ViewBuilder
    private func cameraFinder(size: CGFloat) -> some View {
        ZStack {
            switch configuration.finderStyle {
            case .cornerMarkers:
                CameraCornerMarkers(color: configuration.finderColor ?? configuration.theme.accent)
            case .scanner:
                RoundedRectangle(
                    cornerRadius: configuration.finderCornerRadius,
                    style: .continuous
                )
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.12), .white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: configuration.finderCornerRadius,
                        style: .continuous
                    )
                    .stroke(.white.opacity(0.18), lineWidth: 1)
                }

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                (configuration.finderColor ?? configuration.theme.accent).opacity(0.14),
                                .white.opacity(0.95),
                                (configuration.finderColor ?? configuration.theme.accent).opacity(0.14),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size * 0.70, height: 5)
                    .shadow(
                        color: (configuration.finderColor ?? configuration.theme.accent).opacity(0.38),
                        radius: 14
                    )
                    .offset(y: isFinderAnimating ? size * 0.31 : -size * 0.31)

                CameraCornerMarkers(color: configuration.finderColor ?? configuration.theme.accent)
                    .padding(2)
            }

            if let finderImage {
                Image(uiImage: finderImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: max(size - 18, 0), height: max(size - 18, 0))
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: configuration.finderCornerRadius,
                            style: .continuous
                        )
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: configuration.finderCornerRadius,
                            style: .continuous
                        )
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(
                cornerRadius: configuration.finderCornerRadius,
                style: .continuous
            )
        )
        .shadow(
            color: (configuration.finderColor ?? configuration.theme.accent)
                .opacity(isProcessing ? 0.24 : 0.18),
            radius: isProcessing ? 18 : 10
        )
    }

    private func publishCropFrame() {
        guard !focusFrame.isEmpty, !previewFrame.isEmpty else {
            actions.cropFrameChanged(.zero)
            return
        }
        actions.cropFrameChanged(
            CameraPageGeometry.previewLocalFrame(
                pageFrame: focusFrame,
                previewFrame: previewFrame
            )
        )
    }
}

enum CameraPageGeometry {
    static func previewLocalFrame(
        pageFrame: CGRect,
        previewFrame: CGRect
    ) -> CGRect {
        pageFrame.offsetBy(dx: -previewFrame.minX, dy: -previewFrame.minY)
    }
}

enum CameraPageLayout {
    struct Metrics: Equatable {
        let areaHeight: CGFloat
        let maximumFinderSize: CGFloat
    }

    static func metrics(
        availableHeight: CGFloat,
        configuredMaximumFinderSize: CGFloat
    ) -> Metrics {
        let proportionalHeight = availableHeight * 0.40
        let heightAfterChrome = availableHeight - 250
        let areaHeight = min(
            max(min(proportionalHeight, heightAfterChrome), 120),
            380
        )
        let maximumFinderSize = min(
            configuredMaximumFinderSize,
            max(areaHeight, 96)
        )
        return Metrics(
            areaHeight: areaHeight,
            maximumFinderSize: maximumFinderSize
        )
    }
}

private enum CameraPageCoordinateSpace {
    static let name = "BioScanKit.CameraPage"
}

private struct CameraFocusFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.isEmpty {
            value = next
        }
    }
}

private struct CameraCaptureFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.isEmpty {
            value = next
        }
    }
}

private struct CameraPreviewFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.isEmpty {
            value = next
        }
    }
}

private struct CameraCornerMarkers: View {
    let color: Color
    var lineWidth: CGFloat = 4
    var rounded = true

    var body: some View {
        GeometryReader { proxy in
            let arm = min(proxy.size.width, proxy.size.height) * 0.12

            Path { path in
                path.move(to: CGPoint(x: 0, y: arm))
                path.addLine(to: .zero)
                path.addLine(to: CGPoint(x: arm, y: 0))

                path.move(to: CGPoint(x: proxy.size.width - arm, y: 0))
                path.addLine(to: CGPoint(x: proxy.size.width, y: 0))
                path.addLine(to: CGPoint(x: proxy.size.width, y: arm))

                path.move(to: CGPoint(x: proxy.size.width, y: proxy.size.height - arm))
                path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height))
                path.addLine(to: CGPoint(x: proxy.size.width - arm, y: proxy.size.height))

                path.move(to: CGPoint(x: arm, y: proxy.size.height))
                path.addLine(to: CGPoint(x: 0, y: proxy.size.height))
                path.addLine(to: CGPoint(x: 0, y: proxy.size.height - arm))
            }
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: rounded ? .round : .butt,
                    lineJoin: rounded ? .round : .miter
                )
            )
        }
    }
}
