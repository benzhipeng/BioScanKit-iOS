import BioScanCloudSync
import Foundation
import XCTest

final class CloudFavoriteSnapshotTests: XCTestCase {
    func testSnapshotRoundTripPreservesSyncMetadata() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = CloudFavoriteSnapshot(
            id: "favorite-1",
            sourceCreatedAt: date,
            favoriteModifiedAt: date.addingTimeInterval(10),
            isFavorite: false,
            payload: Data("payload".utf8),
            thumbnailData: Data([1, 2, 3]),
            schemaVersion: 2
        )

        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(CloudFavoriteSnapshot.self, from: encoded)

        XCTAssertEqual(decoded, snapshot)
    }
}
