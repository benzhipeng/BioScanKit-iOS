import AVFoundation
import SwiftUI
import UIKit

public struct CameraPreview: UIViewRepresentable {
    private let session: AVCaptureSession
    private let onFocus: (CGPoint) -> Void

    public init(
        session: AVCaptureSession,
        onFocus: @escaping (CGPoint) -> Void
    ) {
        self.session = session
        self.onFocus = onFocus
    }

    public func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        view.onFocus = onFocus
        return view
    }

    public func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.previewLayer.session = session
        uiView.onFocus = onFocus
    }
}

public final class CameraPreviewView: UIView {
    var onFocus: ((CGPoint) -> Void)?

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    public override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        let devicePoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        onFocus?(devicePoint)
    }
}
