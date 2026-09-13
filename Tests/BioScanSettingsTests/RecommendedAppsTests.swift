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

    func testBuildsLocalizedResourceNameCandidates() {
        let names = RecommendedAppsLoader.localizedResourceNames(
            resourceName: "RecommendedApps",
            preferredLanguages: ["zh-Hans-CN", "en-US"]
        )

        XCTAssertEqual(
            names,
            [
                "RecommendedApps.zh-Hans-CN",
                "RecommendedApps.zh-Hans",
                "RecommendedApps.zh",
                "RecommendedApps.en-US",
                "RecommendedApps.en",
                "RecommendedApps"
            ]
        )
    }

    func testLoadsLocalizedRecommendedAppsJSONBeforeDefault() throws {
        let bundle = try makeBundle(
            files: [
                "RecommendedApps.json": """
                {
                  "apps": [{
                    "id": "mushroom",
                    "title": "Mr.Mushroom",
                    "description": "Mushroom recognition",
                    "appStoreURL": "https://apps.apple.com/app/id123"
                  }]
                }
                """,
                "RecommendedApps.zh-Hans.json": """
                {
                  "apps": [{
                    "id": "mushroom",
                    "title": "Mr.Mushroom",
                    "description": "识别蘑菇并查看安全提示",
                    "appStoreURL": "https://apps.apple.com/app/id123"
                  }]
                }
                """
            ]
        )

        let apps = RecommendedAppsLoader.load(
            bundle: bundle,
            excluding: "inature",
            preferredLanguages: ["zh-Hans-CN"]
        )

        XCTAssertEqual(apps.first?.name, "Mr.Mushroom")
        XCTAssertEqual(apps.first?.subtitle, "识别蘑菇并查看安全提示")
    }

    func testFallsBackToDefaultRecommendedAppsJSON() throws {
        let bundle = try makeBundle(
            files: [
                "RecommendedApps.json": """
                {
                  "apps": [{
                    "id": "mushroom",
                    "title": "Mr.Mushroom",
                    "description": "Mushroom recognition",
                    "appStoreURL": "https://apps.apple.com/app/id123"
                  }]
                }
                """
            ]
        )

        let apps = RecommendedAppsLoader.load(
            bundle: bundle,
            excluding: "inature",
            preferredLanguages: ["fr-FR"]
        )

        XCTAssertEqual(apps.first?.name, "Mr.Mushroom")
        XCTAssertEqual(apps.first?.subtitle, "Mushroom recognition")
    }

    private func makeBundle(files: [String: String]) throws -> Bundle {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        for (name, contents) in files {
            try contents.write(
                to: directory.appendingPathComponent(name),
                atomically: true,
                encoding: .utf8
            )
        }

        return try XCTUnwrap(Bundle(url: directory))
    }
}
