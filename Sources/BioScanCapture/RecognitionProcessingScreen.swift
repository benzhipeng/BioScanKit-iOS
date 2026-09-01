import SwiftUI
import UIKit

public struct RecognitionProcessingScreen: View {
    private let image: UIImage?
    private let configuration: ProcessingScreenConfiguration

    public init(
        image: UIImage?,
        configuration: ProcessingScreenConfiguration = .iNature
    ) {
        self.image = image
        self.configuration = configuration
    }

    public var body: some View {
        Group {
            switch configuration.layoutStyle {
            case .iNatureLegacy:
                LegacyINatureProcessingView(
                    image: image,
                    configuration: configuration
                )
            case .adaptive:
                if let image {
                    AdaptiveProcessingView(
                        image: image,
                        configuration: configuration
                    )
                } else {
                    Color.black.ignoresSafeArea()
                }
            }
        }
    }
}

private struct AdaptiveProcessingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    let image: UIImage
    let configuration: ProcessingScreenConfiguration

    var body: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .blur(radius: 14)
                .overlay(.black.opacity(0.54))
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 4)
                        .frame(width: 92, height: 92)

                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(
                            configuration.theme.accent,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 92, height: 92)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))

                    Image(systemName: "leaf.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                }

                VStack(spacing: 6) {
                    Text(configuration.title)
                        .font(.title2.weight(.black))
                    Text(configuration.subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
            }
            .padding(28)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(configuration.title). \(configuration.subtitle)")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

private struct LegacyINatureProcessingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var hasAppeared = false
    @State private var imageVisible = false
    @State private var markersVisible = false
    @State private var beamVisible = false
    @State private var beamProgress: CGFloat = 0
    @State private var featureProgress: CGFloat = 0
    @State private var statusIndex = 0
    @State private var finalHighlight = false
    @State private var waitingPulse = false
    @State private var ambientGlow = false
    @State private var didStartTimeline = false

    let image: UIImage?
    let configuration: ProcessingScreenConfiguration

    private let statuses = [
        "Preparing scan...",
        "Detecting...",
        "Extracting Features...",
        "Comparing Species...",
        "Waiting for result..."
    ]
    private let cardCornerRadius: CGFloat = 30

    private var isDark: Bool { colorScheme == .dark }
    private var accent: Color {
        configuration.legacyAccent.resolve(for: colorScheme)
    }
    private var accentSoft: Color {
        configuration.legacyAccentSoft.resolve(for: colorScheme)
    }
    private var primaryText: Color {
        isDark
            ? Color(red: 0.95, green: 0.97, blue: 0.96)
            : Color(red: 0.05, green: 0.10, blue: 0.20)
    }
    private var secondaryText: Color {
        isDark
            ? Color(red: 0.70, green: 0.78, blue: 0.74)
            : Color(red: 0.27, green: 0.35, blue: 0.47)
    }

    var body: some View {
        GeometryReader { proxy in
            let horizontalPadding: CGFloat = 22
            let screenSize = UIScreen.main.bounds.size
            let layoutWidth = proxy.size.width > 260 ? proxy.size.width : screenSize.width
            let layoutHeight = proxy.size.height > 500 ? proxy.size.height : screenSize.height
            let availableWidth = max(layoutWidth - horizontalPadding * 2, 260)
            let width = min(availableWidth, 390)
            let cardHeight = min(max(width * 1.08, 330), layoutHeight * 0.54)
            let status = statuses[min(statusIndex, statuses.count - 1)]

            ZStack {
                background

                VStack(spacing: 18) {
                    Spacer(minLength: max(24, layoutHeight * 0.055))

                    ProcessingHeader(
                        status: status,
                        accent: accent,
                        primaryText: primaryText
                    )
                    .frame(width: width)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 10)

                    scanningCard(width: width, height: cardHeight)

                    ProcessingProgressRail(
                        progress: featureProgress,
                        accent: accent,
                        trackColor: secondaryText.opacity(isDark ? 0.24 : 0.18)
                    )
                    .frame(maxWidth: width)
                    .opacity(hasAppeared ? 1 : 0)

                    Spacer(minLength: max(24, layoutHeight * 0.045))
                }
                .frame(width: layoutWidth, height: layoutHeight)
            }
            .frame(width: layoutWidth, height: layoutHeight)
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .task {
            await runTimelineIfNeeded()
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    isDark
                        ? Color(red: 0.08, green: 0.10, blue: 0.10)
                        : Color(red: 0.92, green: 0.94, blue: 0.92),
                    isDark
                        ? Color(red: 0.11, green: 0.15, blue: 0.12)
                        : Color(red: 0.88, green: 0.94, blue: 0.88),
                    isDark
                        ? Color(red: 0.07, green: 0.09, blue: 0.08)
                        : Color(red: 0.95, green: 0.96, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            LinearGradient(
                colors: [
                    isDark ? .black.opacity(0.18) : .white.opacity(0.38),
                    .clear,
                    isDark ? .black.opacity(0.26) : accentSoft.opacity(0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 18) {
                ForEach(0..<14, id: \.self) { _ in
                    Rectangle()
                        .fill(
                            (isDark ? Color.white : accent)
                                .opacity(isDark ? 0.026 : 0.045)
                        )
                        .frame(height: 1)
                }
            }
            .rotationEffect(.degrees(-9))
            .scaleEffect(1.25)

            RadialGradient(
                colors: [
                    accentSoft.opacity(isDark ? 0.20 : 0.34),
                    .clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 360
            )
            .scaleEffect(ambientGlow ? 1.06 : 0.96)
            .opacity(ambientGlow ? 0.72 : 0.48)
        }
    }

    private func scanningCard(width: CGFloat, height: CGFloat) -> some View {
        let innerWidth = max(width - 22, 220)
        let innerHeight = max(height - 22, 260)
        let markerSize = min(max(width - 46, 190), innerHeight - 36)

        return ZStack {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(isDark ? .white.opacity(0.08) : .white.opacity(0.78))
                .overlay {
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .stroke(
                            isDark ? .white.opacity(0.14) : accentSoft.opacity(0.62),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: accent.opacity(isDark ? 0.20 : 0.16),
                    radius: 18,
                    x: 0,
                    y: 12
                )

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: innerWidth, height: innerHeight)
                    .clipShape(.rect(cornerRadius: 24))
                    .overlay(
                        (isDark ? Color.black : Color.white)
                            .opacity(isDark ? 0.10 : 0.06)
                    )
                    .opacity(imageVisible ? 1 : 0)
                    .scaleEffect(imageVisible ? 1 : 0.985)
            }

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(isDark ? 0.24 : 0.62),
                            accent.opacity(isDark ? 0.46 : 0.50),
                            .white.opacity(isDark ? 0.12 : 0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
                .frame(width: innerWidth, height: innerHeight)
                .opacity(markersVisible ? 1 : 0)

            ProcessingCornerMarkers(color: accent)
                .frame(width: markerSize, height: markerSize)
                .opacity(markersVisible ? 0.82 : 0)
                .scaleEffect(markersVisible ? 1 : 0.985)
                .overlay {
                    ProcessingCornerMarkers(
                        color: accent.opacity((finalHighlight || waitingPulse) ? 0.30 : 0)
                    )
                    .frame(width: markerSize + 10, height: markerSize + 10)
                    .scaleEffect((finalHighlight || waitingPulse) ? 1.025 : 1)
                }

            ProcessingFeaturePoints(progress: featureProgress, accent: accent)
                .frame(width: innerWidth, height: innerHeight)
                .clipShape(.rect(cornerRadius: 24))

            scanBeam(height: innerHeight)
                .frame(width: innerWidth, height: innerHeight)
                .clipShape(.rect(cornerRadius: 24))

            ProcessingWaitingPill(
                isVisible: statusIndex >= 4,
                isActive: waitingPulse,
                accent: accent,
                textColor: primaryText,
                backgroundColor: isDark
                    ? .black.opacity(0.32)
                    : .white.opacity(0.76)
            )
            .padding(18)
            .frame(width: width, height: height, alignment: .bottomLeading)
        }
        .frame(width: width, height: height)
        .overlay {
            RoundedRectangle(cornerRadius: cardCornerRadius + 2, style: .continuous)
                .stroke(
                    accent.opacity((finalHighlight || waitingPulse) ? 0.48 : 0.22),
                    lineWidth: finalHighlight ? 2 : 1.2
                )
        }
        .clipped()
    }

    private func scanBeam(height: CGFloat) -> some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .clear,
                            accent.opacity(isDark ? 0.12 : 0.10),
                            accent.opacity(isDark ? 0.54 : 0.42),
                            accent.opacity(isDark ? 0.12 : 0.10),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 88)
                .offset(y: -88 + beamProgress * (height + 176))
                .opacity(beamVisible ? 1 : 0)

            Rectangle()
                .fill(accent.opacity(0.9))
                .frame(height: 2)
                .shadow(color: accent.opacity(0.42), radius: 5)
                .offset(y: -2 + beamProgress * height)
                .opacity(beamVisible ? 1 : 0)
        }
    }

    @MainActor
    private func runTimelineIfNeeded() async {
        guard !didStartTimeline else { return }
        didStartTimeline = true
        resetTimeline()

        guard !reduceMotion else {
            hasAppeared = true
            imageVisible = true
            markersVisible = true
            featureProgress = 0.9
            statusIndex = 4
            return
        }

        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            ambientGlow = true
        }
        withAnimation(.easeOut(duration: 0.42)) {
            hasAppeared = true
        }
        try? await Task.sleep(nanoseconds: 120_000_000)
        withAnimation(.easeOut(duration: 0.48)) {
            imageVisible = true
        }
        try? await Task.sleep(nanoseconds: 180_000_000)
        withAnimation(.easeOut(duration: 0.42)) {
            markersVisible = true
        }
        try? await Task.sleep(nanoseconds: 360_000_000)
        beamVisible = true
        withAnimation(.easeInOut(duration: 2.15)) {
            beamProgress = 1
        }
        withAnimation(.easeInOut(duration: 2.55).delay(0.10)) {
            featureProgress = 0.74
        }
        try? await Task.sleep(nanoseconds: 920_000_000)
        setStatus(1)
        try? await Task.sleep(nanoseconds: 680_000_000)
        setStatus(2)
        try? await Task.sleep(nanoseconds: 760_000_000)
        setStatus(3)
        try? await Task.sleep(nanoseconds: 620_000_000)
        withAnimation(.easeInOut(duration: 1.8)) {
            featureProgress = 0.90
        }
        withAnimation(.easeInOut(duration: 0.36)) {
            finalHighlight = true
        }
        try? await Task.sleep(nanoseconds: 380_000_000)
        setStatus(4)
        withAnimation(.easeInOut(duration: 0.45)) {
            finalHighlight = false
        }
        beamProgress = 0
        withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
            beamProgress = 1
        }
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            waitingPulse = true
        }
        withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
            featureProgress = 0.98
        }
    }

    @MainActor
    private func setStatus(_ index: Int) {
        withAnimation(.easeInOut(duration: 0.25)) {
            statusIndex = min(index, statuses.count - 1)
        }
    }

    @MainActor
    private func resetTimeline() {
        hasAppeared = false
        imageVisible = false
        markersVisible = false
        beamVisible = false
        beamProgress = 0
        featureProgress = 0
        statusIndex = 0
        finalHighlight = false
        waitingPulse = false
        ambientGlow = false
    }
}

private struct ProcessingHeader: View {
    let status: String
    let accent: Color
    let primaryText: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("AI SCAN")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(2.4)
                    .foregroundStyle(accent)

                Text(status)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .contentTransition(.opacity)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
        }
    }
}

private struct ProcessingProgressRail: View {
    let progress: CGFloat
    let accent: Color
    let trackColor: Color

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                    .frame(height: 4)
                Capsule()
                    .fill(accent.opacity(0.92))
                    .frame(width: width * min(max(progress, 0), 1), height: 4)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 4)
    }
}

private struct ProcessingFeaturePoints: View {
    let progress: CGFloat
    let accent: Color

    private let points: [CGPoint] = [
        CGPoint(x: 0.24, y: 0.22),
        CGPoint(x: 0.62, y: 0.18),
        CGPoint(x: 0.42, y: 0.36),
        CGPoint(x: 0.76, y: 0.42),
        CGPoint(x: 0.28, y: 0.56),
        CGPoint(x: 0.58, y: 0.64),
        CGPoint(x: 0.36, y: 0.78),
        CGPoint(x: 0.72, y: 0.76)
    ]

    var body: some View {
        GeometryReader { proxy in
            ForEach(points.indices, id: \.self) { index in
                let threshold = CGFloat(index + 1) / CGFloat(points.count + 1)
                let visibleAmount = min(max((progress - threshold) * 5, 0), 1)
                Circle()
                    .fill(accent.opacity(0.76))
                    .frame(width: 7, height: 7)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.32), lineWidth: 1)
                            .frame(width: 13, height: 13)
                    }
                    .opacity(visibleAmount)
                    .scaleEffect(0.82 + visibleAmount * 0.18)
                    .position(
                        x: proxy.size.width * points[index].x,
                        y: proxy.size.height * points[index].y
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ProcessingWaitingPill: View {
    let isVisible: Bool
    let isActive: Bool
    let accent: Color
    let textColor: Color
    let backgroundColor: Color

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(accent.opacity(0.9))
                .frame(width: 6, height: 6)
                .scaleEffect(isActive ? 1.32 : 0.92)
            Text("Processing")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(0.6)
        }
        .foregroundStyle(textColor.opacity(0.82))
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(backgroundColor, in: Capsule())
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 4)
    }
}

private struct ProcessingCornerMarkers: View {
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size.width
            let length = size * 0.12

            Path { path in
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: .zero)
                path.addLine(to: CGPoint(x: length, y: 0))

                path.move(to: CGPoint(x: size - length, y: 0))
                path.addLine(to: CGPoint(x: size, y: 0))
                path.addLine(to: CGPoint(x: size, y: length))

                path.move(to: CGPoint(x: 0, y: size - length))
                path.addLine(to: CGPoint(x: 0, y: size))
                path.addLine(to: CGPoint(x: length, y: size))

                path.move(to: CGPoint(x: size, y: size - length))
                path.addLine(to: CGPoint(x: size, y: size))
                path.addLine(to: CGPoint(x: size - length, y: size))
            }
            .stroke(color, lineWidth: 3)
        }
    }
}
