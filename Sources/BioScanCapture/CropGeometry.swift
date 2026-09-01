import CoreGraphics
import Foundation

public struct CropLayout: Equatable, Sendable {
    public let canvasFrame: CGRect
    public let cropRect: CGRect
    public let baseScale: CGFloat
    public let minimumZoom: CGFloat

    public init(
        canvasFrame: CGRect,
        cropRect: CGRect,
        baseScale: CGFloat,
        minimumZoom: CGFloat
    ) {
        self.canvasFrame = canvasFrame
        self.cropRect = cropRect
        self.baseScale = baseScale
        self.minimumZoom = minimumZoom
    }
}

public enum CropGeometry {
    /// Maps a rect from an aspect-fill preview into the normalized coordinate
    /// space of the upright source image.
    public static func normalizedSourceRectForAspectFill(
        previewRect: CGRect,
        previewSize: CGSize,
        sourceSize: CGSize
    ) -> CGRect {
        guard previewSize.width > 0,
              previewSize.height > 0,
              sourceSize.width > 0,
              sourceSize.height > 0 else { return .zero }

        let previewBounds = CGRect(origin: .zero, size: previewSize)
        let visiblePreviewRect = previewRect.intersection(previewBounds)
        guard !visiblePreviewRect.isNull, !visiblePreviewRect.isEmpty else { return .zero }

        let scale = max(
            previewSize.width / sourceSize.width,
            previewSize.height / sourceSize.height
        )
        let displayedSize = CGSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )
        let overflow = CGSize(
            width: (displayedSize.width - previewSize.width) / 2,
            height: (displayedSize.height - previewSize.height) / 2
        )
        let sourceRect = CGRect(
            x: (visiblePreviewRect.minX + overflow.width) / scale,
            y: (visiblePreviewRect.minY + overflow.height) / scale,
            width: visiblePreviewRect.width / scale,
            height: visiblePreviewRect.height / scale
        ).intersection(CGRect(origin: .zero, size: sourceSize))

        guard !sourceRect.isNull, !sourceRect.isEmpty else { return .zero }
        return CGRect(
            x: sourceRect.minX / sourceSize.width,
            y: sourceRect.minY / sourceSize.height,
            width: sourceRect.width / sourceSize.width,
            height: sourceRect.height / sourceSize.height
        )
    }

    public static func layout(
        imageSize: CGSize,
        canvasFrame: CGRect,
        cropScale: CGFloat,
        cropMaximumSize: CGFloat? = nil,
        aspectRatio: CGFloat
    ) -> CropLayout {
        let safeImageWidth = max(imageSize.width, 1)
        let safeImageHeight = max(imageSize.height, 1)
        let safeAspectRatio = max(aspectRatio, 0.01)
        let clampedCropScale = min(max(cropScale, 0.1), 1)

        let maximumWidth = canvasFrame.width * clampedCropScale
        let maximumHeight = canvasFrame.height * clampedCropScale
        let maximumConfiguredWidth = cropMaximumSize.map { max($0, 1) }
            ?? .greatestFiniteMagnitude
        let cropWidth = min(
            maximumWidth,
            maximumHeight * safeAspectRatio,
            maximumConfiguredWidth
        )
        let cropHeight = cropWidth / safeAspectRatio
        let cropRect = CGRect(
            x: canvasFrame.midX - cropWidth / 2,
            y: canvasFrame.midY - cropHeight / 2,
            width: cropWidth,
            height: cropHeight
        )

        let baseScale = min(
            canvasFrame.width / safeImageWidth,
            canvasFrame.height / safeImageHeight
        )
        let minimumZoom = max(
            cropRect.width / max(safeImageWidth * baseScale, 1),
            cropRect.height / max(safeImageHeight * baseScale, 1)
        )

        return CropLayout(
            canvasFrame: canvasFrame,
            cropRect: cropRect,
            baseScale: baseScale,
            minimumZoom: minimumZoom
        )
    }

    public static func displayedImageRect(
        imageSize: CGSize,
        canvasFrame: CGRect,
        baseScale: CGFloat,
        zoom: CGFloat,
        offset: CGSize
    ) -> CGRect {
        let width = max(imageSize.width * baseScale * zoom, 1)
        let height = max(imageSize.height * baseScale * zoom, 1)
        return CGRect(
            x: canvasFrame.midX - width / 2 + offset.width,
            y: canvasFrame.midY - height / 2 + offset.height,
            width: width,
            height: height
        )
    }

    public static func clampedOffset(
        _ proposed: CGSize,
        imageRect: CGRect,
        cropRect: CGRect
    ) -> CGSize {
        let currentCenter = CGPoint(x: imageRect.midX, y: imageRect.midY)
        let baseCenter = CGPoint(
            x: currentCenter.x - proposed.width,
            y: currentCenter.y - proposed.height
        )

        let minimumCenterX = cropRect.maxX - imageRect.width / 2
        let maximumCenterX = cropRect.minX + imageRect.width / 2
        let minimumCenterY = cropRect.maxY - imageRect.height / 2
        let maximumCenterY = cropRect.minY + imageRect.height / 2

        let centerX = min(max(currentCenter.x, minimumCenterX), maximumCenterX)
        let centerY = min(max(currentCenter.y, minimumCenterY), maximumCenterY)

        return CGSize(
            width: centerX - baseCenter.x,
            height: centerY - baseCenter.y
        )
    }

    public static func normalizedCropRect(
        cropRect: CGRect,
        imageRect: CGRect
    ) -> CGRect {
        guard imageRect.width > 0, imageRect.height > 0 else { return .zero }

        let normalized = CGRect(
            x: (cropRect.minX - imageRect.minX) / imageRect.width,
            y: (cropRect.minY - imageRect.minY) / imageRect.height,
            width: cropRect.width / imageRect.width,
            height: cropRect.height / imageRect.height
        )

        return normalized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}
