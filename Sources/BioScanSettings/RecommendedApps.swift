import Foundation

public struct RecommendedAppsDocument: Decodable, Sendable {
    public let currentAppID: String?
    public let apps: [RecommendedApp]

    enum CodingKeys: String, CodingKey {
        case currentAppID = "current_app_id"
        case apps
    }

    public init(currentAppID: String?, apps: [RecommendedApp]) {
        self.currentAppID = currentAppID
        self.apps = apps
    }
}

public struct RecommendedApp: Decodable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let appStoreURL: URL
    public let imageName: String?
    public let accentHex: String?
    public let backgroundHexes: [String]
    public let fallbackMessage: String?
    public let isEnabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case subtitle
        case description
        case appStoreURL = "app_store_url"
        case appStoreURLCamel = "appStoreURL"
        case imageName = "image_name"
        case imageNameCamel = "imageName"
        case accentHex = "accent_hex"
        case accentHexCamel = "accentHex"
        case backgroundHexes = "background_colors"
        case backgroundHexesCamel = "backgroundColors"
        case fallbackMessage = "fallback_message"
        case fallbackMessageCamel = "fallbackMessage"
        case isEnabled = "is_enabled"
        case enabled
        case isVisible
    }

    public init(
        id: String,
        name: String,
        subtitle: String,
        appStoreURL: URL,
        imageName: String? = nil,
        accentHex: String? = nil,
        backgroundHexes: [String] = [],
        fallbackMessage: String? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.appStoreURL = appStoreURL
        self.imageName = imageName
        self.accentHex = accentHex
        self.backgroundHexes = backgroundHexes
        self.fallbackMessage = fallbackMessage
        self.isEnabled = isEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
            ?? id
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
            ?? container.decodeIfPresent(String.self, forKey: .description)
            ?? ""
        let urlString = try container.decodeIfPresent(String.self, forKey: .appStoreURL)
            ?? container.decode(String.self, forKey: .appStoreURLCamel)
        guard let parsedURL = URL(string: urlString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .appStoreURL,
                in: container,
                debugDescription: "Invalid App Store URL"
            )
        }
        appStoreURL = parsedURL
        imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
            ?? container.decodeIfPresent(String.self, forKey: .imageNameCamel)
        accentHex = try container.decodeIfPresent(String.self, forKey: .accentHex)
            ?? container.decodeIfPresent(String.self, forKey: .accentHexCamel)
        backgroundHexes = try container.decodeIfPresent([String].self, forKey: .backgroundHexes)
            ?? container.decodeIfPresent([String].self, forKey: .backgroundHexesCamel)
            ?? []
        fallbackMessage = try container.decodeIfPresent(String.self, forKey: .fallbackMessage)
            ?? container.decodeIfPresent(String.self, forKey: .fallbackMessageCamel)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled)
            ?? container.decodeIfPresent(Bool.self, forKey: .enabled)
            ?? container.decodeIfPresent(Bool.self, forKey: .isVisible)
            ?? true
    }
}

public enum RecommendedAppsLoader {
    public static func load(
        resourceName: String = "RecommendedApps",
        bundle: Bundle = .main,
        excluding currentAppID: String
    ) -> [RecommendedApp] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let document = try? JSONDecoder().decode(RecommendedAppsDocument.self, from: data) else {
            return []
        }

        return document.apps.filter {
            $0.isEnabled && $0.id.caseInsensitiveCompare(currentAppID) != .orderedSame
        }
    }
}
