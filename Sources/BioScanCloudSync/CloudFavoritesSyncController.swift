import Foundation

@MainActor
public final class CloudFavoritesSyncController: ObservableObject {
    @Published public private(set) var isEnabled: Bool
    @Published public private(set) var status: CloudFavoritesSyncStatus

    private let defaults: UserDefaults
    private let enabledKey: String
    private let store: any CloudFavoritesStore
    private var engine: CloudFavoritesSyncEngine?
    private let containerIdentifier: String
    private let storageDirectory: URL

    public init(
        appIdentifier: String,
        containerIdentifier: String,
        store: any CloudFavoritesStore,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults
        enabledKey = "\(appIdentifier).icloud-favorites.enabled"
        let initiallyEnabled = defaults.bool(forKey: enabledKey)
        isEnabled = initiallyEnabled
        status = initiallyEnabled ? .checkingAccount : .disabled
        self.store = store
        self.containerIdentifier = containerIdentifier
        storageDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CloudFavorites/\(appIdentifier)", isDirectory: true)
    }

    public func startIfEnabled() {
        guard isEnabled else { return }
        Task { await startEngine() }
    }

    public func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        defaults.set(enabled, forKey: enabledKey)
        if enabled {
            status = .checkingAccount
            Task { await startEngine() }
        } else {
            status = .disabled
            let current = engine
            engine = nil
            Task { await current?.stop() }
        }
    }

    public func favoriteChanged(_ snapshot: CloudFavoriteSnapshot) {
        guard isEnabled else { return }
        Task { await engine?.enqueue(snapshot) }
    }

    public func retry() {
        guard isEnabled else { return }
        Task { await engine?.retry() }
    }

    public func clearFavoritesOnThisDevice() {
        setEnabled(false)
        Task {
            do {
                try await store.clearLocalFavorites()
            } catch {
                status = .failed("Unable to clear favorites")
            }
        }
    }

    public func deleteFavoritesFromiCloud() {
        guard isEnabled else { return }
        Task { await engine?.clearCloudFavorites() }
    }

    private func startEngine() async {
        let syncEngine = CloudFavoritesSyncEngine(
            containerIdentifier: containerIdentifier,
            storageDirectory: storageDirectory,
            store: store
        ) { [weak self] newStatus in
            await self?.receive(newStatus)
        }
        engine = syncEngine
        await syncEngine.start()
    }

    private func receive(_ newStatus: CloudFavoritesSyncStatus) {
        status = newStatus
        if newStatus == .unavailable {
            isEnabled = false
            defaults.set(false, forKey: enabledKey)
        }
    }
}
