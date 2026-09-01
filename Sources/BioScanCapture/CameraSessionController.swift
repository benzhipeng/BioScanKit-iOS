@preconcurrency import AVFoundation
import SwiftUI
import UIKit

public enum CameraPermissionState: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted

    init(status: AVAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .authorized:
            self = .authorized
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        @unknown default:
            self = .denied
        }
    }
}

@MainActor
public final class CameraSessionController: NSObject, ObservableObject {
    @Published public private(set) var permission: CameraPermissionState
    @Published public private(set) var capturedImage: UIImage?
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var zoomFactor: CGFloat = 1
    @Published public private(set) var isRunning = false
    @Published public var flashEnabled = false

    public nonisolated let session = AVCaptureSession()

    private nonisolated let sessionQueue = DispatchQueue(
        label: "BioScanKit.camera.session",
        qos: .userInitiated
    )
    private nonisolated let photoOutput = AVCapturePhotoOutput()
    private var videoDevice: AVCaptureDevice?
    private var isConfigured = false

    public override init() {
        permission = CameraPermissionState(
            status: AVCaptureDevice.authorizationStatus(for: .video)
        )
        super.init()
    }

    public func refreshPermission() {
        permission = CameraPermissionState(
            status: AVCaptureDevice.authorizationStatus(for: .video)
        )
    }

    public func requestPermission() {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard currentStatus == .notDetermined else {
            refreshPermission()
            if currentStatus == .authorized {
                start()
            }
            return
        }

        AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermission()
                if self?.permission == .authorized {
                    self?.start()
                }
            }
        }
    }

    public func start() {
        guard permission == .authorized else { return }
        let needsConfiguration = !isConfigured

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if needsConfiguration {
                self.configureSession()
            }
            guard !self.session.isRunning else { return }
            self.session.startRunning()
            Task { @MainActor in
                self.isRunning = true
            }
        }
    }

    public func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            Task { @MainActor in
                self.isRunning = false
            }
        }
    }

    public func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        if videoDevice?.hasFlash == true {
            settings.flashMode = flashEnabled ? .on : .off
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    public func setZoomFactor(_ factor: CGFloat) {
        guard let device = videoDevice else { return }
        let maximum = min(device.activeFormat.videoMaxZoomFactor, 8)
        let clamped = min(max(factor, 1), maximum)

        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                Task { @MainActor in
                    self?.zoomFactor = clamped
                }
            } catch {
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func focus(at devicePoint: CGPoint) {
        guard let device = videoDevice else { return }

        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch {
                Task { @MainActor in
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    public func clearCapturedImage() {
        capturedImage = nil
    }

    private nonisolated func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            Task { @MainActor in
                self.errorMessage = "The back camera is unavailable."
            }
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
                Task { @MainActor in
                    self.errorMessage = "The camera could not be configured."
                }
                return
            }
            session.addInput(input)
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality

            Task { @MainActor in
                self.videoDevice = device
                self.isConfigured = true
            }
        } catch {
            Task { @MainActor in
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

extension CameraSessionController: AVCapturePhotoCaptureDelegate {
    public nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            Task { @MainActor in
                self.errorMessage = error.localizedDescription
            }
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Task { @MainActor in
                self.errorMessage = "The captured photo could not be processed."
            }
            return
        }

        Task { @MainActor in
            self.capturedImage = BioScanImageProcessing.normalized(image)
        }
    }
}
