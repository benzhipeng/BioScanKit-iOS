import XCTest
@testable import BioScanCapture

final class CropGeometryTests: XCTestCase {
    func testCameraConfigurationKeepsBrandAndInteractionOptions() {
        let configuration = CameraScreenConfiguration(
            title: "Rock Scanner",
            instruction: "Center the rock",
            supportsFlash: false,
            statusText: "Offline",
            finderCornerRadius: 28,
            finderMaximumSize: 320,
            maximumZoomFactor: 6
        )

        XCTAssertEqual(configuration.title, "Rock Scanner")
        XCTAssertEqual(configuration.instruction, "Center the rock")
        XCTAssertFalse(configuration.supportsFlash)
        XCTAssertEqual(configuration.statusText, "Offline")
        XCTAssertEqual(configuration.finderCornerRadius, 28)
        XCTAssertEqual(configuration.finderMaximumSize, 320)
        XCTAssertEqual(configuration.maximumZoomFactor, 6)
    }

    func testINatureFlowPresetsShareCanonicalLayoutAndFinderSize() {
        let camera = CameraScreenConfiguration.iNature(theme: .iNature, title: "Branded Scanner")
        let crop = CropEditorConfiguration.iNature
        let processing = ProcessingScreenConfiguration.iNature

        XCTAssertEqual(camera.layoutStyle, .iNatureLegacy)
        XCTAssertEqual(camera.finderMaximumSize, 300)
        XCTAssertEqual(camera.title, "Branded Scanner")
        XCTAssertEqual(crop.layoutStyle, .iNatureLegacy)
        XCTAssertEqual(crop.cropMaximumSize, camera.finderMaximumSize)
        XCTAssertEqual(processing.layoutStyle, .iNatureLegacy)
    }

    func testCameraPageConvertsFinderFrameIntoPreviewCoordinates() {
        let finderFrame = CGRect(x: 42, y: 180, width: 280, height: 280)
        let previewFrame = CGRect(x: 0, y: 47, width: 390, height: 844)

        XCTAssertEqual(
            CameraPageGeometry.previewLocalFrame(
                pageFrame: finderFrame,
                previewFrame: previewFrame
            ),
            CGRect(x: 42, y: 133, width: 280, height: 280)
        )
    }

    func testAspectFillPreviewMappingPreservesSquareFinderInPortraitPhoto() {
        let mapped = CropGeometry.normalizedSourceRectForAspectFill(
            previewRect: CGRect(x: 46.5, y: 276, width: 300, height: 300),
            previewSize: CGSize(width: 393, height: 852),
            sourceSize: CGSize(width: 3024, height: 4032)
        )

        let mappedPixelWidth = mapped.width * 3024
        let mappedPixelHeight = mapped.height * 4032
        XCTAssertEqual(mapped.midX, 0.5, accuracy: 0.001)
        XCTAssertEqual(mappedPixelWidth, mappedPixelHeight, accuracy: 0.001)
    }

    func testAspectFillPreviewMappingAccountsForCroppedHorizontalEdges() {
        let mapped = CropGeometry.normalizedSourceRectForAspectFill(
            previewRect: CGRect(x: 0, y: 0, width: 393, height: 852),
            previewSize: CGSize(width: 393, height: 852),
            sourceSize: CGSize(width: 3024, height: 4032)
        )

        XCTAssertGreaterThan(mapped.minX, 0)
        XCTAssertLessThan(mapped.maxX, 1)
        XCTAssertEqual(mapped.minY, 0, accuracy: 0.001)
        XCTAssertEqual(mapped.maxY, 1, accuracy: 0.001)
    }

    func testCameraPageLayoutFitsCompactAndRegularHeights() {
        let compact = CameraPageLayout.metrics(
            availableHeight: 390,
            configuredMaximumFinderSize: 300
        )
        let regular = CameraPageLayout.metrics(
            availableHeight: 844,
            configuredMaximumFinderSize: 300
        )

        XCTAssertEqual(compact.areaHeight, 140)
        XCTAssertEqual(compact.maximumFinderSize, 140)
        XCTAssertEqual(regular.areaHeight, 337.6, accuracy: 0.001)
        XCTAssertEqual(regular.maximumFinderSize, 300)
    }

    func testSquareCropIsCenteredAndScaled() {
        let canvas = CGRect(x: 0, y: 100, width: 390, height: 500)
        let layout = CropGeometry.layout(
            imageSize: CGSize(width: 1200, height: 1600),
            canvasFrame: canvas,
            cropScale: 0.78,
            aspectRatio: 1
        )

        XCTAssertEqual(layout.cropRect.midX, canvas.midX, accuracy: 0.001)
        XCTAssertEqual(layout.cropRect.midY, canvas.midY, accuracy: 0.001)
        XCTAssertEqual(layout.cropRect.width, layout.cropRect.height, accuracy: 0.001)
        XCTAssertGreaterThan(layout.minimumZoom, 0)

        let displayed = CropGeometry.displayedImageRect(
            imageSize: CGSize(width: 1200, height: 1600),
            canvasFrame: canvas,
            baseScale: layout.baseScale,
            zoom: layout.minimumZoom,
            offset: .zero
        )
        XCTAssertGreaterThanOrEqual(displayed.width, layout.cropRect.width)
        XCTAssertGreaterThanOrEqual(displayed.height, layout.cropRect.height)
    }

    func testSquareCropRespectsMaximumSize() {
        let layout = CropGeometry.layout(
            imageSize: CGSize(width: 1200, height: 1600),
            canvasFrame: CGRect(x: 0, y: 100, width: 393, height: 500),
            cropScale: 0.78,
            cropMaximumSize: 300,
            aspectRatio: 1
        )

        XCTAssertEqual(layout.cropRect.width, 300, accuracy: 0.001)
        XCTAssertEqual(layout.cropRect.height, 300, accuracy: 0.001)
    }

    func testLandscapeAspectRatioFitsCanvas() {
        let canvas = CGRect(x: 10, y: 20, width: 320, height: 240)
        let layout = CropGeometry.layout(
            imageSize: CGSize(width: 1600, height: 900),
            canvasFrame: canvas,
            cropScale: 0.8,
            aspectRatio: 16.0 / 9.0
        )

        XCTAssertLessThanOrEqual(layout.cropRect.width, canvas.width)
        XCTAssertLessThanOrEqual(layout.cropRect.height, canvas.height)
        XCTAssertEqual(
            layout.cropRect.width / layout.cropRect.height,
            16.0 / 9.0,
            accuracy: 0.001
        )
    }

    func testNormalizedCropRectIsClampedToUnitBounds() {
        let normalized = CropGeometry.normalizedCropRect(
            cropRect: CGRect(x: 0, y: 0, width: 200, height: 200),
            imageRect: CGRect(x: 50, y: 50, width: 100, height: 100)
        )

        XCTAssertEqual(normalized, CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    func testClampedOffsetKeepsImageOverCrop() {
        let crop = CGRect(x: 100, y: 100, width: 200, height: 200)
        let image = CGRect(x: 250, y: 250, width: 300, height: 300)
        let offset = CropGeometry.clampedOffset(
            CGSize(width: 300, height: 300),
            imageRect: image,
            cropRect: crop
        )

        XCTAssertLessThan(offset.width, 300)
        XCTAssertLessThan(offset.height, 300)
    }
}
