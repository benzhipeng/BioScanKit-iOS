import BioScanDesign
import SwiftUI
import UIKit

public protocol PhotoRecognitionClient: Sendable {
    associatedtype Result: Sendable

    func recognize(
        image: UIImage,
        context: RecognitionContext
    ) async throws -> Result
}

public protocol RecognitionAccessControlling: Sendable {
    func currentAccess() async -> RecognitionAccess
    func consumeAfterSuccessfulRecognition() async throws
}

public enum RecognitionAccess: Equatable, Sendable {
    case unlimited
    case credits(Int)
    case unavailable
}

public enum PhotoRecognitionPhase<Result: Sendable>: @unchecked Sendable {
    case camera
    case cropping(CapturedPhoto)
    case recognizing(CapturedPhoto)
    case failed(RecognitionFailure, retry: CapturedPhoto?)
    case completed(Result)
}

@MainActor
public final class PhotoRecognitionStore<
    Client: PhotoRecognitionClient,
    AccessController: RecognitionAccessControlling
>: ObservableObject {
    @Published public private(set) var phase: PhotoRecognitionPhase<Client.Result> = .camera

    private let client: Client
    private let accessController: AccessController
    private let onRequiresPaywall: @MainActor () -> Void
    private let onResult: @MainActor (Client.Result) -> Void
    private var recognitionTask: Task<Void, Never>?
    private let recognitionContinuation = RecognitionContinuation<CapturedPhoto>()

    public init(
        client: Client,
        accessController: AccessController,
        onRequiresPaywall: @escaping @MainActor () -> Void,
        onResult: @escaping @MainActor (Client.Result) -> Void
    ) {
        self.client = client
        self.accessController = accessController
        self.onRequiresPaywall = onRequiresPaywall
        self.onResult = onResult
    }

    deinit {
        recognitionTask?.cancel()
    }

    public func receive(_ photo: CapturedPhoto) {
        phase = .cropping(photo)
    }

    public func cancelCrop() {
        phase = .camera
    }

    public func confirmCrop(_ image: UIImage, context: RecognitionContext) {
        let photo = CapturedPhoto(image: image, context: context)
        startRecognitionIfAllowed(photo)
    }

    public func retry() {
        guard case .failed(_, let photo) = phase, let photo else {
            phase = .camera
            return
        }
        startRecognitionIfAllowed(photo)
    }

    public func resumeAfterPurchase() {
        guard case .resume(let photo) = recognitionContinuation.resolveAfterPaywall(
            hasRecognitionAccess: true
        ) else { return }
        startRecognitionIfAllowed(photo)
    }

    public func reset() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionContinuation.clear()
        phase = .camera
    }

    private func startRecognitionIfAllowed(_ photo: CapturedPhoto) {
        recognitionTask?.cancel()
        recognitionTask = Task { [weak self] in
            guard let self else { return }
            let access = await accessController.currentAccess()
            guard !Task.isCancelled else { return }

            if access == .unavailable {
                recognitionContinuation.enqueue(photo)
                phase = .cropping(photo)
                onRequiresPaywall()
                return
            }

            phase = .recognizing(photo)

            do {
                let result = try await client.recognize(
                    image: photo.image,
                    context: photo.context
                )
                try Task.checkCancellation()
                try await accessController.consumeAfterSuccessfulRecognition()
                try Task.checkCancellation()
                phase = .completed(result)
                onResult(result)
            } catch is CancellationError {
                phase = .camera
            } catch {
                phase = .failed(
                    RecognitionFailure(message: error.localizedDescription),
                    retry: photo
                )
            }
        }
    }
}

public struct PhotoRecognitionFlow<
    Client: PhotoRecognitionClient,
    AccessController: RecognitionAccessControlling
>: View {
    @ObservedObject private var store: PhotoRecognitionStore<Client, AccessController>
    private let configuration: PhotoRecognitionConfiguration
    private let onCancel: () -> Void

    public init(
        store: PhotoRecognitionStore<Client, AccessController>,
        configuration: PhotoRecognitionConfiguration = .iNature,
        onCancel: @escaping () -> Void
    ) {
        self.store = store
        self.configuration = configuration
        self.onCancel = onCancel
    }

    public var body: some View {
        switch store.phase {
        case .camera:
            CameraScreen(
                configuration: configuration.camera,
                onCancel: onCancel,
                onCaptured: store.receive
            )

        case .cropping(let photo):
            ImageCropEditor(
                image: photo.image,
                configuration: configuration.crop,
                onCancel: store.cancelCrop,
                onConfirm: {
                    store.confirmCrop($0, context: photo.context)
                }
            )

        case .recognizing(let photo):
            RecognitionProcessingScreen(
                image: photo.image,
                configuration: configuration.processing
            )

        case .failed(let failure, _):
            RecognitionFailureView(
                failure: failure,
                theme: configuration.camera.theme,
                onRetry: store.retry,
                onCancel: store.reset
            )

        case .completed:
            Color.clear
        }
    }
}

private struct RecognitionFailureView: View {
    let failure: RecognitionFailure
    let theme: BioScanTheme
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(theme.warning)
                .accessibilityHidden(true)
            Text(failure.title)
                .font(.title2.weight(.bold))
            Text(failure.message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
            Button("Back to Camera", action: onCancel)
        }
        .padding(28)
    }
}
