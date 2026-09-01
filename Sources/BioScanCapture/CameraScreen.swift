import SwiftUI

public struct CameraScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @StateObject private var camera = CameraSessionController()
    @State private var showsPhotoPicker = false
    @State private var zoomAtGestureStart: CGFloat = 1

    private let configuration: CameraScreenConfiguration
    private let onCancel: () -> Void
    private let onCaptured: (CapturedPhoto) -> Void

    public init(
        configuration: CameraScreenConfiguration = .iNature,
        onCancel: @escaping () -> Void,
        onCaptured: @escaping (CapturedPhoto) -> Void
    ) {
        self.configuration = configuration
        self.onCancel = onCancel
        self.onCaptured = onCaptured
    }

    public var body: some View {
        Group {
            switch camera.permission {
            case .authorized:
                cameraContent
            case .notDetermined:
                permissionContent(isDenied: false)
            case .denied, .restricted:
                permissionContent(isDenied: true)
            }
        }
        .background(.black)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsPhotoPicker) {
            BioScanPhotoPicker { image in
                onCaptured(
                    CapturedPhoto(
                        image: image,
                        context: RecognitionContext(source: .photoLibrary)
                    )
                )
            }
        }
        .alert(
            "Camera Error",
            isPresented: Binding(
                get: { camera.errorMessage != nil },
                set: { _ in }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(camera.errorMessage ?? "")
        }
        .onAppear {
            camera.refreshPermission()
            if camera.permission == .authorized {
                camera.start()
            }
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: camera.capturedImage) { _ in
            guard let image = camera.capturedImage else { return }
            camera.clearCapturedImage()
            onCaptured(
                CapturedPhoto(
                    image: image,
                    context: RecognitionContext(source: .camera)
                )
            )
        }
        .onChange(of: scenePhase) { _ in
            camera.refreshPermission()
            if scenePhase == .active, camera.permission == .authorized {
                camera.start()
            } else if scenePhase != .active {
                camera.stop()
            }
        }
    }

    private var cameraContent: some View {
        ZStack {
            CameraPreview(session: camera.session) { point in
                guard configuration.supportsTapToFocus else { return }
                camera.focus(at: point)
            }
            .ignoresSafeArea()
            .simultaneousGesture(zoomGesture)

            LinearGradient(
                colors: [.black.opacity(0.52), .clear, .black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                topBar
                Spacer()
                focusFrame
                Spacer()
                controls
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.38), in: Circle())
            }
            .accessibilityLabel("Close camera")

            Spacer()

            Text(configuration.title)
                .font(.headline)

            Spacer()

            if configuration.supportsFlash {
                Button {
                    camera.flashEnabled.toggle()
                } label: {
                    Image(systemName: camera.flashEnabled ? "bolt.fill" : "bolt.slash.fill")
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.38), in: Circle())
                }
                .accessibilityLabel(camera.flashEnabled ? "Turn flash off" : "Turn flash on")
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var focusFrame: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 24)
                .stroke(configuration.theme.accent, lineWidth: 3)
                .frame(maxWidth: 310)
                .aspectRatio(1, contentMode: .fit)
                .shadow(color: configuration.theme.accent.opacity(0.35), radius: 8)

            Text(configuration.instruction)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.4), in: Capsule())
        }
        .padding(.horizontal, 30)
        .allowsHitTesting(false)
    }

    private var controls: some View {
        HStack {
            if configuration.supportsPhotoLibrary {
                Button {
                    showsPhotoPicker = true
                } label: {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .frame(width: 52, height: 52)
                        .background(.white.opacity(0.18), in: Circle())
                }
                .accessibilityLabel("Choose a photo")
            } else {
                Color.clear.frame(width: 52, height: 52)
            }

            Spacer()

            Button {
                camera.capturePhoto()
            } label: {
                Circle()
                    .fill(.white)
                    .frame(width: 76, height: 76)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.5), lineWidth: 4)
                            .frame(width: 88, height: 88)
                    }
            }
            .accessibilityLabel("Take photo")

            Spacer()

            Text(String(format: "%.1fx", camera.zoomFactor))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(.black.opacity(0.38), in: Circle())
                .accessibilityLabel("Zoom \(String(format: "%.1f", camera.zoomFactor)) times")
        }
        .padding(.horizontal, 30)
        .padding(.bottom, 28)
    }

    private var permissionContent: some View {
        permissionContent(isDenied: camera.permission != .notDetermined)
    }

    private func permissionContent(isDenied: Bool) -> some View {
        VStack(spacing: 18) {
            Image(systemName: isDenied ? "camera.fill.badge.ellipsis" : "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(configuration.theme.accent)
                .accessibilityHidden(true)

            Text(configuration.permissionTitle)
                .font(.title2.weight(.black))
                .foregroundStyle(.white)

            Text(isDenied ? configuration.deniedMessage : configuration.permissionMessage)
                .font(.body)
                .foregroundStyle(.white.opacity(0.76))
                .multilineTextAlignment(.center)

            Button(isDenied ? "Open Settings" : "Continue") {
                if isDenied {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                } else {
                    camera.requestPermission()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(configuration.theme.accent)

            if configuration.supportsPhotoLibrary {
                Button("Choose from Photos") {
                    showsPhotoPicker = true
                }
                .foregroundStyle(.white)
            }

            Button("Cancel", action: onCancel)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(28)
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard configuration.supportsPinchToZoom else { return }
                camera.setZoomFactor(zoomAtGestureStart * value)
            }
            .onEnded { _ in
                zoomAtGestureStart = camera.zoomFactor
            }
    }
}
