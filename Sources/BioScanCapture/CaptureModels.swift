import BioScanDesign
import CoreLocation
import Foundation
import SwiftUI
import UIKit

public enum CameraFinderStyle: Equatable, Sendable {
    case cornerMarkers
    case scanner
}

public enum CameraPageLayoutStyle: Equatable, Sendable {
    /// Preserves the original iNature camera hierarchy and control metrics.
    case iNatureLegacy
    /// Adapts the finder area and controls to compact and regular screen heights.
    case adaptive
}

public struct CameraScreenConfiguration: Sendable {
    public let theme: BioScanTheme
    public let title: String
    public let instruction: String
    public let permissionTitle: String
    public let permissionMessage: String
    public let deniedMessage: String
    public let supportsPhotoLibrary: Bool
    public let supportsFlash: Bool
    public let supportsTapToFocus: Bool
    public let supportsPinchToZoom: Bool
    public let statusText: String?
    public let processingInstruction: String
    public let finderCornerRadius: CGFloat
    public let finderMaximumSize: CGFloat
    public let finderStyle: CameraFinderStyle
    public let finderColor: Color?
    public let layoutStyle: CameraPageLayoutStyle
    public let maximumZoomFactor: CGFloat
    public let statusSystemImage: String
    public let statusForegroundColor: Color
    public let closeAccessibilityLabel: String
    public let helpAccessibilityLabel: String
    public let galleryAccessibilityLabel: String
    public let captureAccessibilityLabel: String
    public let flashOnAccessibilityLabel: String
    public let flashOffAccessibilityLabel: String

    public init(
        theme: BioScanTheme = .iNature,
        title: String = "Identify",
        instruction: String = "Center your subject inside the frame",
        permissionTitle: String = "Camera Access",
        permissionMessage: String = "Allow camera access to photograph and identify your subject.",
        deniedMessage: String = "Camera access is disabled. You can enable it in Settings.",
        supportsPhotoLibrary: Bool = true,
        supportsFlash: Bool = true,
        supportsTapToFocus: Bool = true,
        supportsPinchToZoom: Bool = true,
        statusText: String? = "On-device recognition",
        processingInstruction: String = "Analyzing subject…",
        finderCornerRadius: CGFloat = 24,
        finderMaximumSize: CGFloat = 310,
        finderStyle: CameraFinderStyle = .cornerMarkers,
        finderColor: Color? = nil,
        layoutStyle: CameraPageLayoutStyle = .adaptive,
        maximumZoomFactor: CGFloat = 8,
        statusSystemImage: String = "cpu",
        statusForegroundColor: Color = .white.opacity(0.94),
        closeAccessibilityLabel: String = "Close camera",
        helpAccessibilityLabel: String = "Show camera tips",
        galleryAccessibilityLabel: String = "Choose a photo",
        captureAccessibilityLabel: String = "Take photo",
        flashOnAccessibilityLabel: String = "Turn flash off",
        flashOffAccessibilityLabel: String = "Turn flash on"
    ) {
        self.theme = theme
        self.title = title
        self.instruction = instruction
        self.permissionTitle = permissionTitle
        self.permissionMessage = permissionMessage
        self.deniedMessage = deniedMessage
        self.supportsPhotoLibrary = supportsPhotoLibrary
        self.supportsFlash = supportsFlash
        self.supportsTapToFocus = supportsTapToFocus
        self.supportsPinchToZoom = supportsPinchToZoom
        self.statusText = statusText
        self.processingInstruction = processingInstruction
        self.finderCornerRadius = finderCornerRadius
        self.finderMaximumSize = finderMaximumSize
        self.finderStyle = finderStyle
        self.finderColor = finderColor
        self.layoutStyle = layoutStyle
        self.maximumZoomFactor = maximumZoomFactor
        self.statusSystemImage = statusSystemImage
        self.statusForegroundColor = statusForegroundColor
        self.closeAccessibilityLabel = closeAccessibilityLabel
        self.helpAccessibilityLabel = helpAccessibilityLabel
        self.galleryAccessibilityLabel = galleryAccessibilityLabel
        self.captureAccessibilityLabel = captureAccessibilityLabel
        self.flashOnAccessibilityLabel = flashOnAccessibilityLabel
        self.flashOffAccessibilityLabel = flashOffAccessibilityLabel
    }

    public static let iNature = CameraScreenConfiguration(
        finderMaximumSize: 300,
        finderColor: Color(red: 0.18, green: 0.55, blue: 0.24),
        layoutStyle: .iNatureLegacy
    )

    /// Creates an app-branded camera while preserving the canonical iNature
    /// geometry. Apps may customize content and appearance, but the finder size
    /// and page hierarchy stay aligned with the crop and processing screens.
    public static func iNature(
        theme: BioScanTheme,
        title: String = "Identify",
        instruction: String = "Center your subject inside the frame",
        permissionTitle: String = "Camera Access",
        permissionMessage: String = "Allow camera access to photograph and identify your subject.",
        deniedMessage: String = "Camera access is disabled. You can enable it in Settings.",
        supportsPhotoLibrary: Bool = true,
        supportsFlash: Bool = true,
        supportsTapToFocus: Bool = true,
        supportsPinchToZoom: Bool = true,
        statusText: String? = "On-device recognition",
        processingInstruction: String = "Analyzing subject…",
        finderCornerRadius: CGFloat = 24,
        finderStyle: CameraFinderStyle = .cornerMarkers,
        finderColor: Color? = nil,
        maximumZoomFactor: CGFloat = 6,
        statusSystemImage: String = "cpu",
        statusForegroundColor: Color = .white.opacity(0.94),
        closeAccessibilityLabel: String = "Close camera",
        helpAccessibilityLabel: String = "Show camera tips",
        galleryAccessibilityLabel: String = "Choose a photo",
        captureAccessibilityLabel: String = "Take photo",
        flashOnAccessibilityLabel: String = "Turn flash off",
        flashOffAccessibilityLabel: String = "Turn flash on"
    ) -> CameraScreenConfiguration {
        CameraScreenConfiguration(
            theme: theme,
            title: title,
            instruction: instruction,
            permissionTitle: permissionTitle,
            permissionMessage: permissionMessage,
            deniedMessage: deniedMessage,
            supportsPhotoLibrary: supportsPhotoLibrary,
            supportsFlash: supportsFlash,
            supportsTapToFocus: supportsTapToFocus,
            supportsPinchToZoom: supportsPinchToZoom,
            statusText: statusText,
            processingInstruction: processingInstruction,
            finderCornerRadius: finderCornerRadius,
            finderMaximumSize: 300,
            finderStyle: finderStyle,
            finderColor: finderColor,
            layoutStyle: .iNatureLegacy,
            maximumZoomFactor: maximumZoomFactor,
            statusSystemImage: statusSystemImage,
            statusForegroundColor: statusForegroundColor,
            closeAccessibilityLabel: closeAccessibilityLabel,
            helpAccessibilityLabel: helpAccessibilityLabel,
            galleryAccessibilityLabel: galleryAccessibilityLabel,
            captureAccessibilityLabel: captureAccessibilityLabel,
            flashOnAccessibilityLabel: flashOnAccessibilityLabel,
            flashOffAccessibilityLabel: flashOffAccessibilityLabel
        )
    }
}

public enum CropBorderAnimationStyle: Sendable {
    case none
    case pulse
}

public enum CropEditorLayoutStyle: Sendable {
    case iNatureLegacy
    case adaptive
}

public struct CropEditorConfiguration: Sendable {
    public let theme: BioScanTheme
    public let aspectRatio: CGFloat
    public let cropScale: CGFloat
    public let cropMaximumSize: CGFloat?
    public let cornerRadius: CGFloat
    public let showsGrid: Bool
    public let showsPreview: Bool
    public let allowsReset: Bool
    public let guidanceText: String
    public let confirmTitle: String
    public let animationStyle: CropBorderAnimationStyle
    public let layoutStyle: CropEditorLayoutStyle
    public let hidesStatusBar: Bool
    public let legacyAccent: Color

    public init(
        theme: BioScanTheme = .iNature,
        aspectRatio: CGFloat = 1,
        cropScale: CGFloat = 0.78,
        cropMaximumSize: CGFloat? = nil,
        cornerRadius: CGFloat = 14,
        showsGrid: Bool = true,
        showsPreview: Bool = true,
        allowsReset: Bool = true,
        guidanceText: String = "Center your subject inside the frame",
        confirmTitle: String = "Identify",
        animationStyle: CropBorderAnimationStyle = .pulse,
        layoutStyle: CropEditorLayoutStyle = .adaptive,
        hidesStatusBar: Bool = true,
        legacyAccent: Color = .green
    ) {
        self.theme = theme
        self.aspectRatio = aspectRatio
        self.cropScale = cropScale
        self.cropMaximumSize = cropMaximumSize
        self.cornerRadius = cornerRadius
        self.showsGrid = showsGrid
        self.showsPreview = showsPreview
        self.allowsReset = allowsReset
        self.guidanceText = guidanceText
        self.confirmTitle = confirmTitle
        self.animationStyle = animationStyle
        self.layoutStyle = layoutStyle
        self.hidesStatusBar = hidesStatusBar
        self.legacyAccent = legacyAccent
    }

    public static let iNature = CropEditorConfiguration(
        cropMaximumSize: 300,
        confirmTitle: "Use Crop",
        animationStyle: .none,
        layoutStyle: .iNatureLegacy,
        hidesStatusBar: false
    )

    public static func iNature(
        theme: BioScanTheme,
        guidanceText: String = "Center your subject inside the frame",
        confirmTitle: String = "Use Crop"
    ) -> CropEditorConfiguration {
        CropEditorConfiguration(
            theme: theme,
            cropMaximumSize: 300,
            guidanceText: guidanceText,
            confirmTitle: confirmTitle,
            animationStyle: .none,
            layoutStyle: .iNatureLegacy,
            hidesStatusBar: false,
            legacyAccent: theme.accent
        )
    }
}

public struct ProcessingScreenConfiguration: Sendable {
    public let theme: BioScanTheme
    public let title: String
    public let subtitle: String
    public let layoutStyle: ProcessingScreenLayoutStyle
    public let legacyAccent: AdaptiveColor
    public let legacyAccentSoft: AdaptiveColor

    public init(
        theme: BioScanTheme = .iNature,
        title: String = "Analyzing",
        subtitle: String = "Comparing visual features on this device…",
        layoutStyle: ProcessingScreenLayoutStyle = .adaptive,
        legacyAccent: AdaptiveColor = AdaptiveColor(
            light: Color(red: 0.15, green: 0.53, blue: 0.20),
            dark: Color(red: 0.44, green: 0.82, blue: 0.48)
        ),
        legacyAccentSoft: AdaptiveColor = AdaptiveColor(
            light: Color(red: 0.55, green: 0.79, blue: 0.57),
            dark: Color(red: 0.54, green: 0.92, blue: 0.58)
        )
    ) {
        self.theme = theme
        self.title = title
        self.subtitle = subtitle
        self.layoutStyle = layoutStyle
        self.legacyAccent = legacyAccent
        self.legacyAccentSoft = legacyAccentSoft
    }

    public static let iNature = ProcessingScreenConfiguration(
        layoutStyle: .iNatureLegacy
    )

    public static func iNature(
        theme: BioScanTheme,
        title: String = "Analyzing",
        subtitle: String = "Comparing visual features on this device…"
    ) -> ProcessingScreenConfiguration {
        ProcessingScreenConfiguration(
            theme: theme,
            title: title,
            subtitle: subtitle,
            layoutStyle: .iNatureLegacy,
            legacyAccent: AdaptiveColor(light: theme.accent, dark: theme.accent),
            legacyAccentSoft: AdaptiveColor(
                light: theme.accent.opacity(0.72),
                dark: theme.accent.opacity(0.82)
            )
        )
    }
}

public enum ProcessingScreenLayoutStyle: Sendable {
    case iNatureLegacy
    case adaptive
}

public struct PhotoRecognitionConfiguration: Sendable {
    public let camera: CameraScreenConfiguration
    public let crop: CropEditorConfiguration
    public let processing: ProcessingScreenConfiguration

    public init(
        camera: CameraScreenConfiguration = .iNature,
        crop: CropEditorConfiguration = .iNature,
        processing: ProcessingScreenConfiguration = .iNature
    ) {
        self.camera = camera
        self.crop = crop
        self.processing = processing
    }

    public static let iNature = PhotoRecognitionConfiguration()
}

public struct CapturedPhoto: Identifiable, @unchecked Sendable {
    public let id: UUID
    public let image: UIImage
    public let context: RecognitionContext

    public init(
        id: UUID = UUID(),
        image: UIImage,
        context: RecognitionContext
    ) {
        self.id = id
        self.image = image
        self.context = context
    }
}

public struct RecognitionContext: @unchecked Sendable {
    public enum Source: Sendable {
        case camera
        case photoLibrary
        case guideDemo
    }

    public let source: Source
    public let location: CLLocationCoordinate2D?
    public let isGuideDemo: Bool

    public init(
        source: Source,
        location: CLLocationCoordinate2D? = nil,
        isGuideDemo: Bool = false
    ) {
        self.source = source
        self.location = location
        self.isGuideDemo = isGuideDemo
    }
}

public struct RecognitionFailure: Error, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let message: String

    public init(
        id: UUID = UUID(),
        title: String = "Recognition Failed",
        message: String
    ) {
        self.id = id
        self.title = title
        self.message = message
    }
}
