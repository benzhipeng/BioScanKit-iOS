import Foundation

public struct CloudFavoriteSnapshot: Codable, Hashable, Sendable {
    public let id: String
    public let sourceCreatedAt: Date
    public let favoriteModifiedAt: Date
    public let isFavorite: Bool
    public let payload: Data
    public let thumbnailData: Data?
    public let schemaVersion: Int

    public init(
        id: String,
        sourceCreatedAt: Date,
        favoriteModifiedAt: Date = .now,
        isFavorite: Bool = true,
        payload: Data,
        thumbnailData: Data? = nil,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.sourceCreatedAt = sourceCreatedAt
        self.favoriteModifiedAt = favoriteModifiedAt
        self.isFavorite = isFavorite
        self.payload = payload
        self.thumbnailData = thumbnailData
        self.schemaVersion = schemaVersion
    }
}

@MainActor
public protocol CloudFavoritesStore: AnyObject {
    func localFavoriteSnapshots() async throws -> [CloudFavoriteSnapshot]
    func applyRemoteFavorite(_ snapshot: CloudFavoriteSnapshot) async throws
    func applyRemoteRemoval(id: String, modifiedAt: Date) async throws
    func clearLocalFavorites() async throws
}

public enum CloudFavoritesSyncStatus: Equatable, Sendable {
    case disabled
    case checkingAccount
    case syncing
    case synced(Date)
    case unavailable
    case failed(String)

    public var subtitle: String {
        switch self {
        case .disabled:
            return "Keep favorites on this device only"
        case .checkingAccount:
            return "Checking iCloud availability..."
        case .syncing:
            return "Syncing favorites..."
        case .synced:
            return "Favorites are up to date"
        case .unavailable:
            return "Sign in to iCloud to sync favorites"
        case .failed(let message):
            return message
        }
    }
}
