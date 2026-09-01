# iCloud Favorites Sync Development Plan

## 1. Scope

Implement opt-in iCloud favorite synchronization for the iOS versions of:

1. Mr.Rock (`My Pocket`, `SavedScan.isPocketed`)
2. iNature (`HistoryItem.isFavorite`)
3. Mushroom (`MushroomHistoryItem.isFavorite`)
4. Mr.Fish (`SavedCatch.isFavorite`)
5. NatureEar (`FavoriteItem`)

All apps use CloudKit private databases through `CKSyncEngine`. Mr.Rock and
iNature move their minimum deployment target from iOS 16 to iOS 17.

## 2. Product Behavior

### Sync switch

- The switch is off by default so existing local photos are not uploaded without
  an explicit user action.
- Enabling sync checks the iCloud account, creates the private record zone,
  uploads local favorites, fetches cloud favorites, and merges both collections.
- Disabling sync stops future uploads and downloads. It keeps both local and
  cloud data intact.
- The settings row reports Disabled, Checking iCloud, Syncing, Up to Date,
  iCloud Unavailable, or an actionable error.

### Clear actions

- **Clear Favorites on This Device** removes the favorite state and imported
  cloud-only favorite snapshots locally. It does not write remote deletions.
- **Delete Favorites from iCloud** writes a collection clear watermark and
  removes favorites locally. Other enabled devices apply the same clear.
- Existing history clearing remains separate. History clearing must enqueue
  remote removals for any synchronized favorites it removes.

## 3. Cloud Architecture

Each app owns an independent CloudKit container and private database:

| App | Container |
| --- | --- |
| Mr.Rock | `iCloud.com.drseries.drrock` |
| iNature | `iCloud.com.binghe.iNature` |
| Mushroom | `iCloud.com.zhuoben.drmushroom` |
| Mr.Fish | `iCloud.com.zhuoben.drfish` |
| NatureEar | `iCloud.com.zhuoben.NatureEar` |

All containers use a custom record zone named `FavoritesZone`.

### `Favorite` record

| Field | Type | Purpose |
| --- | --- | --- |
| record name | String | Stable local UUID/string ID |
| `schemaVersion` | Int64 | Payload migration version |
| `sourceCreatedAt` | Date | Original recognition time |
| `favoriteModifiedAt` | Date | Conflict ordering |
| `isFavorite` | Int64 | Favorite state/tombstone |
| `payload` | Bytes | App-owned Codable metadata |
| `thumbnail` | Asset, optional | Compressed display image |

### `FavoritesState` record

The record name is `collection-state`. Its `clearedAt` date is the global clear
watermark. A favorite whose `favoriteModifiedAt` is not newer than `clearedAt`
must not be restored.

## 4. Shared Module

Add `BioScanCloudSync` to `BioScanKit/iOS`.

Public responsibilities:

- `CloudFavoriteSnapshot`: common favorite transport model.
- `CloudFavoritesStore`: app adapter protocol for local reads and writes.
- `CloudFavoritesSyncController`: observable UI-facing state and commands.
- `CloudFavoritesSyncEngine`: `CKSyncEngine` delegate and CloudKit mapping.
- Durable pending payload and engine-state persistence.
- Idempotent merging, tombstones, clear watermark handling, retries, and account
  changes.

App adapters remain in each app because their models and image stores differ.

## 5. Settings UI

Add a shared `SettingsCloudFavoritesSectionView` to `BioScanSettings` with:

- iCloud Favorites toggle.
- Current sync status and last successful sync time.
- Retry action for recoverable failures.
- Clear Favorites on This Device.
- Delete Favorites from iCloud.
- Confirmation dialogs that state the exact scope of deletion.

The view receives a `CloudFavoritesSyncController` and the app theme. It does
not own domain persistence.

## 6. App Adapter Requirements

Every adapter must:

1. Export existing local favorites as snapshots.
2. Apply remote favorite state by explicit assignment, never by toggling.
3. Materialize cloud-only favorites with enough metadata and a cached thumbnail
   to render existing favorite screens.
4. Remove cloud-imported records when they are no longer favorites, while
   retaining normal local history records.
5. Notify the sync controller after local favorite changes.
6. Preserve favorites when enforcing local history limits.

NatureEar Watch continues to send favorite actions to the iPhone. The iPhone is
the CloudKit sync owner for the first release.

## 7. Project Configuration

For every app target:

- Enable iCloud with CloudKit.
- Enable remote notifications (`aps-environment`).
- Add the app-specific iCloud container entitlement.
- Add `remote-notification` to background modes where required.
- Ensure the application target links `BioScanCloudSync`.
- Deploy the development CloudKit schema to production before App Store release.

## 8. Testing

### Unit tests

- Snapshot coding and CloudKit record mapping.
- Last-modified conflict resolution.
- Clear watermark rejection.
- Idempotent repeated remote events.
- Pending-change persistence and retry.
- Local-only clear versus cloud clear.

### Integration tests

- Existing-user first enable and initial merge.
- Two devices adding and removing the same favorite.
- Offline mutation followed by reconnect.
- Clear on one device while another device is offline.
- iCloud sign-out, sign-in, and account switch.
- Missing or failed thumbnail asset.
- Upgrade, reinstall, and new-device restore.

## 9. Execution Order

1. Add the shared package target, core models, sync engine, tests, and settings UI.
2. Integrate Mushroom as the reference adapter.
3. Integrate Mr.Rock My Pocket.
4. Integrate Mr.Fish.
5. Integrate iNature and raise its deployment target.
6. Integrate NatureEar and verify the Watch-to-iPhone path.
7. Add entitlements and CloudKit containers to all five projects.
8. Run package tests, project generation, simulator builds, and archive entitlement
   checks.

## 10. Acceptance Criteria

- A favorite created on one signed-in device appears on another.
- A removal and a global clear cannot be undone by a stale offline device.
- Turning sync off never deletes data.
- Local-only clear does not mutate CloudKit.
- All favorite screens remain usable without a network connection.
- Existing favorites migrate without user-visible duplication.
- All five application targets build with their production entitlements.

## 11. Execution Result (2026-08-16)

### Completed

- Added the shared `BioScanCloudSync` package target, `CKSyncEngine` engine,
  durable pending state, tombstones, conflict timestamps, and persistent clear
  watermark.
- Added the shared settings section with an opt-in switch, status, retry,
  local-only clear, cloud clear, and confirmation dialogs.
- Integrated Mushroom, Mr.Rock My Pocket, Mr.Fish, iNature, and NatureEar local
  models and stores. Cloud-only records retain enough metadata and thumbnail
  data to render offline.
- NatureEar keeps the iPhone as the CloudKit owner; Watch favorite events still
  flow through the existing phone session.
- Added CloudKit, push notification, and background notification configuration
  to all five app projects. Mr.Rock and iNature now target iOS 17.
- Added snapshot coding unit coverage and verified the shared CloudKit module
  directly against the iOS 17 SDK.
- Added server-record reconciliation before uploads so a reinstall or lost local
  `CKSyncEngine` state does not repeatedly try to insert an existing record.
- Exported and validated the five Development schemas under `CloudKitSchemas/`.

### Build verification

| Target | Result |
| --- | --- |
| Mr.Fish, iOS Simulator | Passed |
| Mushroom, iOS Simulator | Passed |
| Mr.Rock, arm64 iOS Simulator | Passed |
| iNature workspace, arm64 iOS Simulator | Passed |
| NatureEar + Watch, generic iOS device | Passed |
| Entitlement and Info plist syntax | Passed for all five apps |
| Mr.Rock, iNature, Mushroom, NatureEar, signed physical device | Passed |
| Development schema validation with `cktool` | Passed for all five containers |

Build output still contains existing deprecation, actor-isolation, asset catalog,
and build-script warnings outside this feature.

### Release prerequisites

Apple Developer configuration completed on 2026-08-16:

- Confirmed all five Bundle IDs and enabled `ICLOUD` with the `XCODE_6`
  CloudKit option.
- Enabled Push Notifications for all five phone App IDs.
- Created or associated the five iCloud containers listed in section 3 through
  Xcode automatic provisioning.
- Regenerated managed development provisioning profiles and verified that all
  five signed device builds contain `CloudKit`, the expected container, and
  `aps-environment` entitlements.
- Kept NatureEar Watch phone-mediated; its Watch App ID does not own a separate
  CloudKit container.
- Configured Debug builds for the Development CloudKit environment and Release
  builds for Production in all five app projects.
- Generated `Favorite`, `FavoritesState`, and `Users` in all five Development
  containers. Both sync record types include all required fields, including the
  optional thumbnail asset and collection clear timestamp.
- Deployed all five schemas to Production and confirmed the deployments on
  2026-08-16 by exporting each Production schema with `cktool`. Every container
  contains the complete `Favorite`, `FavoritesState`, and `Users` record types.
- `cktool validate-schema` is only applicable to Development; the Production
  verification uses a successful export plus field-level comparison instead.

Remaining release verification:

1. Execute the two-device, offline, account-switch, reinstall, and global-clear
   integration cases from section 8 before App Store submission.
2. Revoke and replace the CloudKit management token used during setup because
   it was shared in chat.
