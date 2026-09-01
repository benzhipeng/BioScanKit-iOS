import XCTest
@testable import BioScanSettings

final class RecommendedAppsTests: XCTestCase {
    func testDecodesSnakeCaseDocument() throws {
        let data = Data(
            """
            {
              "current_app_id": "inature",
              "apps": [{
                "id": "mushroom",
                "name": "Mr.Mushroom",
                "subtitle": "Identify mushrooms",
                "app_store_url": "https://apps.apple.com/app/id123",
                "image_name": "MushroomLogo",
                "is_enabled": true
              }]
            }
            """.utf8
        )

        let document = try JSONDecoder().decode(
            RecommendedAppsDocument.self,
            from: data
        )

        XCTAssertEqual(document.currentAppID, "inature")
        XCTAssertEqual(document.apps.first?.name, "Mr.Mushroom")
        XCTAssertEqual(document.apps.first?.imageName, "MushroomLogo")
    }
}
