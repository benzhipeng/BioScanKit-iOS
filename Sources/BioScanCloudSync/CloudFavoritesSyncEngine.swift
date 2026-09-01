import CloudKit
import Foundation
import os

@available(iOS 17.0, *)
public actor CloudFavoritesSyncEngine: CKSyncEngineDelegate {
    private static let logger = Logger(subsystem: "BioScanCloudSync", category: "Favorites")
    private enum RecordType {
        static let favorite = "Favorite"
        static let state = "FavoritesState"
    }

    private enum Field {
        static let schemaVersion = "schemaVersion"
        static let sourceCreatedAt = "sourceCreatedAt"
        static let favoriteModifiedAt = "favoriteModifiedAt"
        static let isFavorite = "isFavorite"
        static let payload = "payload"
        static let thumbnail = "thumbnail"
        static let clearedAt = "clearedAt"
    }

    private struct PersistedPending: Codable {
        var snapshots: [String: CloudFavoriteSnapshot] = [:]
        var clearedAt: Date?
        var stateNeedsUpload: Bool?
    }

    public static let zoneName = "FavoritesZone"
    public static let stateRecordName = "collection-state"

    private let container: CKContainer
    private let database: CKDatabase
    private let zoneID: CKRecordZone.ID
    private let store: any CloudFavoritesStore
    private let storageDirectory: URL
    private let statusHandler: @Sendable (CloudFavoritesSyncStatus) async -> Void
    private var pending = PersistedPending()
    private var clearedAt: Date?
    private var temporaryAssetURLs: [CKRecord.ID: URL] = [:]
    private var serverRecords: [CKRecord.ID: CKRecord] = [:]
    private var engine: CKSyncEngine?

    public init(
        containerIdentifier: String,
        storageDirectory: URL,
        store: any CloudFavoritesStore,
        statusHandler: @escaping @Sendable (CloudFavoritesSyncStatus) async -> Void
    ) {
        container = CKContainer(identifier: containerIdentifier)
        database = container.privateCloudDatabase
        zoneID = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
        self.storageDirectory = storageDirectory
        self.store = store
        self.statusHandler = statusHandler
    }

    public func start() async {
        let containerName = self.container.containerIdentifier ?? "unknown"
        Self.logger.info("Starting iCloud favorites sync for container \(containerName, privacy: .public), zone \(Self.zoneName, privacy: .public)")
        await statusHandler(.checkingAccount)
        do {
            let accountStatus = try await container.accountStatus()
            Self.logger.info("iCloud account status: \(String(describing: accountStatus), privacy: .public)")
            guard accountStatus == .available else {
                await statusHandler(.unavailable)
                return
            }
            try loadPersistedState()
            try await ensureZone()
            let engine = makeEngine()
            self.engine = engine
            try await enqueueInitialFavorites(in: engine)
            await statusHandler(.syncing)
            try await engine.fetchChanges()
            try await engine.sendChanges()
            await statusHandler(.synced(.now))
        } catch {
            if let cloudError = error as? CKError {
                Self.logger.error("CloudKit sync failed: code=\(cloudError.code.rawValue, privacy: .public), description=\(cloudError.localizedDescription, privacy: .public)")
            } else {
                Self.logger.error("iCloud sync failed: \(error.localizedDescription, privacy: .public)")
            }
            await statusHandler(.failed(Self.message(for: error)))
        }
    }

    public func stop() async {
        await engine?.cancelOperations()
        engine = nil
    }

    public func enqueue(_ snapshot: CloudFavoriteSnapshot) async {
        pending.snapshots[snapshot.id] = snapshot
        persistPending()
        guard let engine else { return }
        let recordID = favoriteRecordID(snapshot.id)
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(recordID)])
        await sendPendingChanges(with: engine)
    }

    public func clearCloudFavorites() async {
        let date = Date()
        clearedAt = date
        pending.clearedAt = date
        pending.stateNeedsUpload = true
        persistPending()
        do {
            try await store.clearLocalFavorites()
        } catch {
            await statusHandler(.failed(Self.message(for: error)))
        }
        guard let engine else { return }
        engine.state.add(pendingRecordZoneChanges: [.saveRecord(stateRecordID)])
        await sendPendingChanges(with: engine)
    }

    public func retry() async {
        guard let engine else {
            await start()
            return
        }
        await statusHandler(.syncing)
        do {
            try await engine.fetchChanges()
            try await engine.sendChanges()
            await statusHandler(.synced(.now))
        } catch {
            await statusHandler(.failed(Self.message(for: error)))
        }
    }

    public func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        switch event {
        case .stateUpdate(let update):
            persistEngineState(update.stateSerialization)
        case .accountChange:
            await statusHandler(.checkingAccount)
        case .fetchedRecordZoneChanges(let changes):
            await applyFetchedChanges(changes)
        case .sentRecordZoneChanges(let changes):
            await handleSentChanges(changes)
        case .didFetchChanges, .didSendChanges:
            await statusHandler(.synced(.now))
        case .willFetchChanges, .willSendChanges:
            await statusHandler(.syncing)
        default:
            break
        }
    }

    public func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let changes = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { [weak self] recordID in
            guard let self else { return nil }
            return await self.record(for: recordID)
        }
    }

    private func makeEngine() -> CKSyncEngine {
        let configuration = CKSyncEngine.Configuration(
            database: database,
            stateSerialization: loadEngineState(),
            delegate: self
        )
        return CKSyncEngine(configuration)
    }

    private func ensureZone() async throws {
        do {
            _ = try await database.save(CKRecordZone(zoneID: zoneID))
        } catch let error as CKError where error.code == .serverRejectedRequest || error.code == .zoneNotFound {
            throw error
        } catch let error as CKError where error.code == .partialFailure {
            throw error
        } catch {
            if let cloudError = error as? CKError, cloudError.code == .serverRecordChanged {
                return
            }
            throw error
        }
    }

    private func enqueueInitialFavorites(in engine: CKSyncEngine) async throws {
        let snapshots = try await store.localFavoriteSnapshots()
        for snapshot in snapshots {
            if let existing = pending.snapshots[snapshot.id],
               existing.favoriteModifiedAt > snapshot.favoriteModifiedAt {
                continue
            }
            pending.snapshots[snapshot.id] = snapshot
        }

        try await reconcilePendingSnapshotsWithServer()
        persistPending()
        let changes = pending.snapshots.keys.map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord(favoriteRecordID($0))
        }
        if !changes.isEmpty {
            engine.state.add(pendingRecordZoneChanges: changes)
        }
        if pending.stateNeedsUpload == true {
            engine.state.add(pendingRecordZoneChanges: [.saveRecord(stateRecordID)])
        }
    }

    private func record(for recordID: CKRecord.ID) -> CKRecord? {
        if recordID.recordName == Self.stateRecordName, let date = pending.clearedAt {
            let record = serverRecords[recordID] ?? CKRecord(recordType: RecordType.state, recordID: recordID)
            record[Field.clearedAt] = date as CKRecordValue
            record[Field.schemaVersion] = NSNumber(value: 1)
            return record
        }
        guard let snapshot = pending.snapshots[recordID.recordName] else { return nil }
        let record = serverRecords[recordID] ?? CKRecord(recordType: RecordType.favorite, recordID: recordID)
        record[Field.schemaVersion] = NSNumber(value: snapshot.schemaVersion)
        record[Field.sourceCreatedAt] = snapshot.sourceCreatedAt as CKRecordValue
        record[Field.favoriteModifiedAt] = snapshot.favoriteModifiedAt as CKRecordValue
        record[Field.isFavorite] = NSNumber(value: snapshot.isFavorite)
        record[Field.payload] = snapshot.payload as CKRecordValue
        if let thumbnailData = snapshot.thumbnailData,
           let url = try? writeTemporaryAsset(thumbnailData, id: snapshot.id) {
            temporaryAssetURLs[recordID] = url
            record[Field.thumbnail] = CKAsset(fileURL: url)
        }
        return record
    }

    private func applyFetchedChanges(_ changes: CKSyncEngine.Event.FetchedRecordZoneChanges) async {
        let records = changes.modifications.map(\.record)
        if let state = records.first(where: { $0.recordType == RecordType.state }),
           let remoteClearedAt = state[Field.clearedAt] as? Date,
           clearedAt == nil || remoteClearedAt > clearedAt! {
            clearedAt = remoteClearedAt
            pending.clearedAt = remoteClearedAt
            pending.stateNeedsUpload = false
            engine?.state.remove(pendingRecordZoneChanges: [.saveRecord(stateRecordID)])
            let staleIDs = pending.snapshots.values.compactMap { snapshot in
                snapshot.favoriteModifiedAt <= remoteClearedAt ? snapshot.id : nil
            }
            for id in staleIDs {
                discardPendingSnapshot(id: id)
            }
            persistPending()
            try? await store.clearLocalFavorites()
        }

        for record in records where record.recordType == RecordType.favorite {
            guard let snapshot = snapshot(from: record) else { continue }
            if let local = pending.snapshots[snapshot.id],
               snapshot.favoriteModifiedAt >= local.favoriteModifiedAt {
                discardPendingSnapshot(id: snapshot.id)
            }
            if let clearedAt, snapshot.favoriteModifiedAt <= clearedAt { continue }
            do {
                if snapshot.isFavorite {
                    try await store.applyRemoteFavorite(snapshot)
                } else {
                    try await store.applyRemoteRemoval(id: snapshot.id, modifiedAt: snapshot.favoriteModifiedAt)
                }
            } catch {
                await statusHandler(.failed(Self.message(for: error)))
            }
        }
        for deletion in changes.deletions where deletion.recordType == RecordType.favorite {
            try? await store.applyRemoteRemoval(id: deletion.recordID.recordName, modifiedAt: .now)
        }
    }

    private func snapshot(from record: CKRecord) -> CloudFavoriteSnapshot? {
        guard let createdAt = record[Field.sourceCreatedAt] as? Date,
              let modifiedAt = record[Field.favoriteModifiedAt] as? Date,
              let payload = record[Field.payload] as? Data else {
            return nil
        }
        let isFavorite = (record[Field.isFavorite] as? NSNumber)?.boolValue ?? true
        let version = (record[Field.schemaVersion] as? NSNumber)?.intValue ?? 1
        let thumbnailData = (record[Field.thumbnail] as? CKAsset)?.fileURL.flatMap { try? Data(contentsOf: $0) }
        return CloudFavoriteSnapshot(
            id: record.recordID.recordName,
            sourceCreatedAt: createdAt,
            favoriteModifiedAt: modifiedAt,
            isFavorite: isFavorite,
            payload: payload,
            thumbnailData: thumbnailData,
            schemaVersion: version
        )
    }

    private func handleSentChanges(_ changes: CKSyncEngine.Event.SentRecordZoneChanges) async {
        for record in changes.savedRecords {
            if record.recordType == RecordType.favorite {
                pending.snapshots.removeValue(forKey: record.recordID.recordName)
            } else if record.recordType == RecordType.state {
                pending.stateNeedsUpload = false
            }
            serverRecords.removeValue(forKey: record.recordID)
            cleanupTemporaryAsset(for: record.recordID)
        }

        for failure in changes.failedRecordSaves where failure.error.code == .serverRecordChanged {
            guard let serverRecord = failure.error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord else {
                continue
            }
            await resolveConflict(with: serverRecord)
        }
        persistPending()
    }

    private func reconcilePendingSnapshotsWithServer() async throws {
        var recordIDs = pending.snapshots.keys.map(favoriteRecordID)
        if pending.stateNeedsUpload == true {
            recordIDs.append(stateRecordID)
        }
        let desiredKeys = [
            Field.schemaVersion,
            Field.sourceCreatedAt,
            Field.favoriteModifiedAt,
            Field.isFavorite,
            Field.payload,
            Field.thumbnail,
            Field.clearedAt,
        ]

        for batchStart in stride(from: 0, to: recordIDs.count, by: 200) {
            let batchEnd = min(batchStart + 200, recordIDs.count)
            let results = try await database.records(
                for: Array(recordIDs[batchStart..<batchEnd]),
                desiredKeys: desiredKeys
            )
            for (recordID, result) in results {
                switch result {
                case .success(let serverRecord):
                    await resolveConflict(with: serverRecord)
                case .failure(let error as CKError) where error.code == .unknownItem:
                    break
                case .failure(let error):
                    throw error
                }
                if recordID != stateRecordID, pending.snapshots[recordID.recordName] == nil {
                    serverRecords.removeValue(forKey: recordID)
                }
            }
        }
    }

    private func resolveConflict(with serverRecord: CKRecord) async {
        if serverRecord.recordType == RecordType.state,
           let remoteClearedAt = serverRecord[Field.clearedAt] as? Date,
           let localClearedAt = pending.clearedAt {
            if localClearedAt > remoteClearedAt {
                serverRecords[serverRecord.recordID] = serverRecord
                engine?.state.add(pendingRecordZoneChanges: [.saveRecord(serverRecord.recordID)])
            } else {
                clearedAt = remoteClearedAt
                pending.clearedAt = remoteClearedAt
                pending.stateNeedsUpload = false
                engine?.state.remove(pendingRecordZoneChanges: [.saveRecord(serverRecord.recordID)])
                try? await store.clearLocalFavorites()
            }
            return
        }

        guard serverRecord.recordType == RecordType.favorite,
              let remote = snapshot(from: serverRecord),
              let local = pending.snapshots[remote.id] else {
            return
        }

        if local.favoriteModifiedAt > remote.favoriteModifiedAt {
            serverRecords[serverRecord.recordID] = serverRecord
            engine?.state.add(pendingRecordZoneChanges: [.saveRecord(serverRecord.recordID)])
            return
        }

        discardPendingSnapshot(id: remote.id)
        do {
            if remote.isFavorite {
                try await store.applyRemoteFavorite(remote)
            } else {
                try await store.applyRemoteRemoval(id: remote.id, modifiedAt: remote.favoriteModifiedAt)
            }
        } catch {
            await statusHandler(.failed(Self.message(for: error)))
        }
    }

    private func discardPendingSnapshot(id: String) {
        pending.snapshots.removeValue(forKey: id)
        engine?.state.remove(pendingRecordZoneChanges: [.saveRecord(favoriteRecordID(id))])
    }

    private func sendPendingChanges(with engine: CKSyncEngine) async {
        await statusHandler(.syncing)
        do {
            try await engine.sendChanges()
            await statusHandler(.synced(.now))
        } catch {
            await statusHandler(.failed(Self.message(for: error)))
        }
    }

    private var stateRecordID: CKRecord.ID {
        CKRecord.ID(recordName: Self.stateRecordName, zoneID: zoneID)
    }

    private func favoriteRecordID(_ id: String) -> CKRecord.ID {
        CKRecord.ID(recordName: id, zoneID: zoneID)
    }

    private var pendingURL: URL { storageDirectory.appendingPathComponent("pending.json") }
    private var engineStateURL: URL { storageDirectory.appendingPathComponent("engine-state.json") }

    private func loadPersistedState() throws {
        try FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: pendingURL),
           let value = try? JSONDecoder().decode(PersistedPending.self, from: data) {
            pending = value
            clearedAt = value.clearedAt
        }
    }

    private func persistPending() {
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(pending) else { return }
        try? data.write(to: pendingURL, options: .atomic)
    }

    private func loadEngineState() -> CKSyncEngine.State.Serialization? {
        guard let data = try? Data(contentsOf: engineStateURL) else { return nil }
        return try? JSONDecoder().decode(CKSyncEngine.State.Serialization.self, from: data)
    }

    private func persistEngineState(_ state: CKSyncEngine.State.Serialization) {
        try? FileManager.default.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: engineStateURL, options: .atomic)
    }

    private func writeTemporaryAsset(_ data: Data, id: String) throws -> URL {
        let directory = storageDirectory.appendingPathComponent("Assets", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(id)-\(UUID().uuidString).jpg")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func cleanupTemporaryAsset(for recordID: CKRecord.ID) {
        guard let url = temporaryAssetURLs.removeValue(forKey: recordID) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func message(for error: Error) -> String {
        if let cloudError = error as? CKError {
            switch cloudError.code {
            case .notAuthenticated:
                return "Sign in to iCloud to sync favorites"
            case .networkUnavailable, .networkFailure:
                return "Waiting for a network connection"
            case .quotaExceeded:
                return "iCloud storage is full"
            default:
                return "iCloud sync needs attention"
            }
        }
        return "iCloud sync needs attention"
    }
}
