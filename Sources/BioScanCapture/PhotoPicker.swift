import PhotosUI
import SwiftUI

public struct BioScanPhotoPicker: UIViewControllerRepresentable {
    private let onImage: (UIImage) -> Void

    public init(onImage: @escaping (UIImage) -> Void) {
        self.onImage = onImage
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    public func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(
        _ uiViewController: PHPickerViewController,
        context: Context
    ) {}

    public final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onImage: (UIImage) -> Void

        init(onImage: @escaping (UIImage) -> Void) {
            self.onImage = onImage
        }

        public func picker(
            _ picker: PHPickerViewController,
            didFinishPicking results: [PHPickerResult]
        ) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }

            provider.loadObject(ofClass: UIImage.self) { [onImage] object, _ in
                guard let image = object as? UIImage else { return }
                DispatchQueue.main.async {
                    onImage(BioScanImageProcessing.normalized(image))
                }
            }
        }
    }
}
