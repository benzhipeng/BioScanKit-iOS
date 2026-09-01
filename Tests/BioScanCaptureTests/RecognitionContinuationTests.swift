import XCTest
@testable import BioScanCapture

@MainActor
final class RecognitionContinuationTests: XCTestCase {
    func testResumesPendingInputWhenAccessIsAvailable() {
        let continuation = RecognitionContinuation<String>()
        continuation.enqueue("photo")

        let resolution = continuation.resolveAfterPaywall(
            hasRecognitionAccess: true
        )

        guard case .resume(let input) = resolution else {
            return XCTFail("Expected the pending input to resume")
        }
        XCTAssertEqual(input, "photo")
        XCTAssertFalse(continuation.hasPendingInput)
    }

    func testDiscardsPendingInputWhenPaywallClosesWithoutAccess() {
        let continuation = RecognitionContinuation<String>()
        continuation.enqueue("photo")

        let resolution = continuation.resolveAfterPaywall(
            hasRecognitionAccess: false
        )

        guard case .discard = resolution else {
            return XCTFail("Expected the pending input to be discarded")
        }
        XCTAssertFalse(continuation.hasPendingInput)
    }

    func testReportsWhenThereIsNoPendingInput() {
        let continuation = RecognitionContinuation<String>()

        let resolution = continuation.resolveAfterPaywall(
            hasRecognitionAccess: true
        )

        guard case .noPendingInput = resolution else {
            return XCTFail("Expected no pending input")
        }
    }

    func testLatestInputReplacesPreviousInput() {
        let continuation = RecognitionContinuation<String>()
        continuation.enqueue("first")
        continuation.enqueue("latest")

        let resolution = continuation.resolveAfterPaywall(
            hasRecognitionAccess: true
        )

        guard case .resume(let input) = resolution else {
            return XCTFail("Expected the latest input to resume")
        }
        XCTAssertEqual(input, "latest")
    }
}
