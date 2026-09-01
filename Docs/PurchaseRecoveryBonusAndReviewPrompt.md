# Purchase Recovery Bonus and Review Prompt

## 1. Document Status

- Status: Proposed implementation specification
- Initial locale: English (`en`)
- Platforms: iOS first; Android may reuse the recovery model without the iOS review API
- Shared module: `BioScanKit`
- Intended apps: Fish, Mushroom, NatureEar, Mr.Rock, plantCam, and future BioScanKit apps

## 2. Objective

Improve conversion recovery and long-term retention when a user opens a paywall but cancels the purchase flow.

The feature has two independent parts:

1. Offer an unconditional, one-time grant of 10 recognition credits after an eligible purchase cancellation.
2. Request an App Store review later, after the user completes a successful recognition with the granted credits.

The review request must never be presented as a condition for receiving credits. The app must not ask specifically for a five-star rating and must not attempt to verify whether a rating was submitted.

## 3. Compliance Requirements

### 3.1 Prohibited behavior

Do not implement any of the following:

- "Give us five stars to receive 10 scans."
- A reward that is granted only after opening the App Store review page.
- A reward that depends on the number of stars selected.
- A custom star-rating control used to filter satisfied users before invoking the system review prompt.
- A claim that the app can detect whether the user rated or reviewed it.
- Repeated review prompts after every purchase cancellation.

### 3.2 Required separation

The recovery reward and review request are separate state machines:

- The recovery reward is granted when the user explicitly accepts the recovery offer.
- The review request becomes eligible only after a later successful core experience.
- Review prompt display is controlled by StoreKit and is never guaranteed.
- No credit ledger entry may reference review completion.

### 3.3 Apple references

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Requesting App Store reviews](https://developer.apple.com/documentation/storekit/requesting-app-store-reviews)
- [Ratings and reviews](https://developer.apple.com/app-store/ratings-and-reviews/)

## 4. User Experience

### 4.1 Eligible entry point

Show the recovery offer only after all of the following are true:

- The paywall was presented from an eligible recognition-credit purchase flow.
- StoreKit or RevenueCat reports that the user cancelled the purchase.
- The user does not have lifetime or unlimited access.
- The recovery campaign has not already been claimed.
- The recovery offer has not already been dismissed during the configured cooldown.
- No error, system alert, or another modal is currently visible.

Do not show the offer after:

- A billing error.
- A network failure.
- A pending purchase.
- A successful purchase.
- A restore-purchases operation.
- A parental approval or Ask to Buy pending state.

### 4.2 Recovery offer

Present the offer after the paywall has fully dismissed. Use a delay of approximately 500 milliseconds to avoid competing transitions.

Recommended English copy:

| Element | Copy |
| --- | --- |
| Eyebrow | `A little more time to explore` |
| Title | `Enjoy 10 more identifications` |
| Body | `Not ready to purchase? Keep exploring with 10 complimentary identifications.` |
| Primary action | `Claim 10 identifications` |
| Secondary action | `Maybe later` |
| Success message | `10 identifications added` |

Copy requirements:

- Do not mention ratings, reviews, stars, or the App Store.
- Do not imply that a purchase is required later.
- Clearly state the exact credit amount.
- Use the app-specific domain noun only when it improves clarity, for example `fish identifications`.

### 4.3 Review request

Do not request a review immediately after the user cancels a purchase or claims the bonus. A cancellation is not a positive experience milestone.

The review request becomes eligible after:

- The bonus was claimed.
- At least one recognition completed successfully after the claim.
- The result screen became visible without an error.
- The app is active and no modal is being presented.
- The current app version has not already attempted this campaign review request.

Wait approximately 1 to 2 seconds after the successful result is visible, then call SwiftUI's `RequestReviewAction` or the appropriate StoreKit API. Do not show a custom pre-prompt.

StoreKit may decide not to display the prompt. Treat the API call as an attempt, not a confirmed review.

## 5. State Model

Use a campaign-scoped state record. The initial campaign identifier is:

```text
purchase-exit-recovery-v1
```

Suggested states:

```swift
public enum PurchaseRecoveryState: String, Codable, Sendable {
    case eligible
    case offerPresented
    case offerDismissed
    case claimInProgress
    case claimed
    case successfulUseCompleted
    case reviewRequestAttempted
    case ineligible
}
```

Required persisted fields:

```swift
public struct PurchaseRecoveryRecord: Codable, Sendable {
    public let campaignID: String
    public var state: PurchaseRecoveryState
    public var offerPresentedAt: Date?
    public var offerDismissedAt: Date?
    public var claimedAt: Date?
    public var grantedCredits: Int
    public var successfulUsesAfterClaim: Int
    public var reviewRequestAttemptedAt: Date?
    public var appVersionAtReviewAttempt: String?
}
```

### 5.1 State transitions

```text
Purchase cancelled
       |
       v
   eligible
       |
       v
offerPresented ------> offerDismissed
       |
       v
claimInProgress
       |
       +---- failure ----> eligible
       |
       v
    claimed
       |
       v
successfulUseCompleted
       |
       v
reviewRequestAttempted
```

The transition from `claimInProgress` to `claimed` must occur only after the credit ledger confirms the grant.

## 6. Shared BioScanKit Architecture

Add a shared feature module or place the implementation in the existing paywall domain if that boundary already owns purchase outcomes.

Suggested package product:

```swift
.library(
    name: "BioScanPurchaseRecovery",
    targets: ["BioScanPurchaseRecovery"]
)
```

Suggested dependencies:

- `BioScanDesign` for the recovery sheet.
- The app-owned billing adapter for purchase outcomes.
- The app-owned credit ledger through a protocol.
- StoreKit only in the iOS review-request adapter.

### 6.1 Configuration

```swift
public struct PurchaseRecoveryConfiguration: Sendable {
    public let campaignID: String
    public let bonusCredits: Int
    public let dismissalCooldown: Duration
    public let successfulUsesBeforeReviewRequest: Int
    public let theme: BioScanTheme

    public init(
        campaignID: String = "purchase-exit-recovery-v1",
        bonusCredits: Int = 10,
        dismissalCooldown: Duration = .days(30),
        successfulUsesBeforeReviewRequest: Int = 1,
        theme: BioScanTheme
    )
}
```

If `Duration.days` is not available in the supported toolchain, store the cooldown as `TimeInterval`.

### 6.2 Credit ledger protocol

```swift
public protocol RecoveryCreditGranting: Sendable {
    func currentAccess() async -> RecognitionAccess
    func hasClaimedRecoveryCampaign(_ campaignID: String) async throws -> Bool
    func grantRecoveryCredits(
        _ amount: Int,
        campaignID: String,
        idempotencyKey: String
    ) async throws
}
```

Requirements:

- Granting must be atomic.
- `idempotencyKey` must prevent duplicate credits when a request is retried.
- A successful grant must be reflected in the normal credit balance immediately.
- The ledger entry should use a source such as `purchase_recovery_bonus`.
- The grant must not contain any review-related metadata.

### 6.3 Persistence protocol

```swift
public protocol PurchaseRecoveryPersisting: Sendable {
    func record(for campaignID: String) async throws -> PurchaseRecoveryRecord?
    func save(_ record: PurchaseRecoveryRecord) async throws
}
```

Preferred storage order:

1. Account-backed server storage when an account exists.
2. iCloud key-value or CloudKit state when appropriate for the app.
3. Keychain for device-local persistence across reinstalls.
4. `UserDefaults` only as a non-authoritative presentation cache.

Server-side or account-backed persistence is recommended when bonus credits have monetary value.

### 6.4 Coordinator

```swift
@MainActor
public final class PurchaseRecoveryCoordinator: ObservableObject {
    @Published public private(set) var presentation: PurchaseRecoveryPresentation?
    @Published public private(set) var isClaiming = false

    public func handlePurchaseOutcome(_ outcome: BillingOutcome) async
    public func claimBonus() async
    public func dismissOffer() async
    public func recordSuccessfulRecognition() async
    public func consumeReviewRequestEligibility() async -> Bool
}
```

The coordinator owns eligibility and state transitions. Views must not calculate campaign eligibility independently.

## 7. Billing Outcome Contract

Normalize RevenueCat and StoreKit results before passing them to the coordinator:

```swift
public enum BillingOutcome: Sendable {
    case purchased(productID: String)
    case userCancelled(productID: String?)
    case pending(productID: String?)
    case failed(code: String)
    case restored
}
```

Only `.userCancelled` can start the recovery flow.

RevenueCat cancellation errors must be mapped carefully. Do not infer cancellation from every thrown error. Use RevenueCat's explicit user-cancelled signal.

## 8. SwiftUI Presentation

### 8.1 Recovery sheet

The shared recovery sheet should accept theme and copy configuration but own its layout and accessibility behavior.

```swift
public struct PurchaseRecoverySheet: View {
    public let presentation: PurchaseRecoveryPresentation
    public let theme: BioScanTheme
    public let claim: () -> Void
    public let dismiss: () -> Void
}
```

Presentation requirements:

- Use one primary and one secondary action.
- Disable the primary action while granting credits.
- Show an inline progress state without changing sheet dimensions.
- Preserve Dynamic Type support.
- Provide VoiceOver labels that include the credit amount.
- Do not dismiss until the credit grant succeeds.
- Show a recoverable error with Retry and Not Now actions.

### 8.2 App integration

Each app supplies only:

- Its `BioScanTheme`.
- Its credit-ledger adapter.
- Its billing outcome adapter.
- Optional domain-specific English copy.

Example:

```swift
.sheet(item: $recoveryCoordinator.presentation) { presentation in
    PurchaseRecoverySheet(
        presentation: presentation,
        theme: AppBioScanStyle.theme,
        claim: { Task { await recoveryCoordinator.claimBonus() } },
        dismiss: { Task { await recoveryCoordinator.dismissOffer() } }
    )
}
```

On a successful recognition result:

```swift
await recoveryCoordinator.recordSuccessfulRecognition()

if await recoveryCoordinator.consumeReviewRequestEligibility() {
    try? await Task.sleep(for: .seconds(1.5))
    requestReview()
}
```

Before calling `requestReview()`, confirm that the scene is active and that no sheet, alert, paywall, or navigation transition is in progress.

## 9. English Localization

English is the initial required locale. Do not hard-code production copy in Swift. Add string-catalog keys:

```text
purchaseRecovery.eyebrow
purchaseRecovery.title
purchaseRecovery.body
purchaseRecovery.claim
purchaseRecovery.dismiss
purchaseRecovery.claiming
purchaseRecovery.success
purchaseRecovery.error.title
purchaseRecovery.error.body
purchaseRecovery.retry
```

Default English values:

```text
purchaseRecovery.eyebrow = A little more time to explore
purchaseRecovery.title = Enjoy 10 more identifications
purchaseRecovery.body = Not ready to purchase? Keep exploring with 10 complimentary identifications.
purchaseRecovery.claim = Claim 10 identifications
purchaseRecovery.dismiss = Maybe later
purchaseRecovery.claiming = Adding identifications...
purchaseRecovery.success = 10 identifications added
purchaseRecovery.error.title = Could not add identifications
purchaseRecovery.error.body = Please check your connection and try again.
purchaseRecovery.retry = Try Again
```

Use a format argument for the credit count in the final implementation so experiments can change the amount without inconsistent copy.

## 10. Analytics

All apps must emit the same event names and parameter schema.

### 10.1 Events

```text
purchase_recovery_eligible
purchase_recovery_offer_shown
purchase_recovery_offer_claim_tap
purchase_recovery_offer_dismissed
purchase_recovery_grant_succeeded
purchase_recovery_grant_failed
purchase_recovery_successful_use
purchase_recovery_review_request_eligible
purchase_recovery_review_request_attempted
```

### 10.2 Common parameters

```text
app_id
campaign_id
product_id
paywall_id
paywall_trigger
bonus_credits
credits_before
credits_after
membership_tier
app_version
days_since_install
error_code
```

Never emit a `review_completed`, `review_rating`, or `five_star_review` event because the app cannot observe those outcomes.

### 10.3 Funnel

Measure:

```text
Offer shown
  -> Claim tapped
  -> Grant succeeded
  -> Successful recognition
  -> Review request attempted
  -> Later purchase conversion
```

The product success metric should prioritize retained users and later conversion, not an unverifiable review-completion rate.

## 11. Abuse Prevention

- Use one claim per campaign per account when account identity exists.
- Use an idempotent ledger entry for every claim.
- Persist the claim independently of app deletion when feasible.
- Do not reset eligibility when the app version changes.
- Do not grant again after switching devices on the same account.
- Rate-limit claim attempts.
- Record suspicious duplicate attempts without blocking normal offline recovery unnecessarily.

If the app has no account or server ledger, Keychain persistence is the minimum acceptable protection. Document that this is weaker than account-backed enforcement.

## 12. Error Handling

| Condition | Behavior |
| --- | --- |
| User cancels purchase | Evaluate recovery eligibility |
| Billing error | Show normal billing error; no recovery offer |
| Grant network failure | Keep sheet open and show Retry |
| Duplicate idempotency key | Treat as success and refresh balance |
| App backgrounds during grant | Finish safely; restore state on foreground |
| Review API does not show UI | Mark request as attempted; do not retry immediately |
| User dismisses offer | Store dismissal timestamp and apply cooldown |
| User has unlimited access | Do not show offer |

## 13. Testing Strategy

### 13.1 Unit tests

Cover:

- Cancellation is the only eligible billing outcome.
- Paid and unlimited users are ineligible.
- A claimed campaign cannot be claimed twice.
- An idempotent retry does not double the balance.
- Dismissal cooldown is respected.
- A successful recognition before claiming does not trigger review eligibility.
- A successful recognition after claiming does trigger eligibility.
- Review eligibility is consumed once.
- Billing failures never show the recovery offer.
- State survives coordinator recreation.

### 13.2 UI tests

Cover:

- Offer appears only after the paywall dismisses.
- Claim button enters a stable loading state.
- Success updates the visible credit balance.
- Failure supports retry.
- Dynamic Type does not clip English copy.
- VoiceOver announces the bonus amount and button purpose.
- iPhone SE and large iPhone layouts do not overlap.
- iPad presentation uses an appropriate sheet width.

Do not attempt to automate the actual App Store rating submission. Inject a review-request spy and verify only that the request action was invoked when eligible.

### 13.3 Billing sandbox tests

Test each app with:

- User cancellation.
- Successful purchase.
- Failed purchase.
- Pending purchase where supported.
- Restore purchase.
- Offline cancellation and foreground recovery.

## 14. Rollout Plan

### Phase 1: Shared implementation

- Add shared model, persistence protocol, coordinator, and sheet.
- Add unit tests.
- Add English string-catalog entries.
- Add analytics contracts.

### Phase 2: First app integration

- Integrate one low-risk app.
- Enable the recovery offer for internal/TestFlight users.
- Verify ledger idempotency and analytics.
- Confirm that the review request occurs only after a successful recognition.

### Phase 3: Multi-app rollout

- Integrate Fish, Mushroom, NatureEar, Mr.Rock, and plantCam through adapters.
- Keep the campaign ID consistent only if claim policy is per app.
- Prefix the campaign ID with the app ID if each app should grant its own bonus.
- Compare claim rate, successful-use rate, and later purchase conversion.

### Phase 4: Production experiment

- Use a remote feature flag.
- Start with a small percentage of eligible users.
- Keep the bonus fixed at 10 during the first experiment.
- Stop the experiment if billing support contacts, duplicate grants, or crashes increase.

## 15. Feature Flags

Suggested remote configuration:

```json
{
  "purchase_recovery_enabled": true,
  "purchase_recovery_campaign_id": "purchase-exit-recovery-v1",
  "purchase_recovery_bonus_credits": 10,
  "purchase_recovery_dismissal_cooldown_days": 30,
  "purchase_recovery_review_after_successes": 1
}
```

Validate remote values locally:

- Bonus credits: `1...50`
- Cooldown days: `1...365`
- Successful uses before review: `1...10`
- Campaign ID: non-empty, stable, and ASCII-safe

## 16. Acceptance Criteria

The feature is complete when:

- Every target app uses the shared coordinator and recovery sheet.
- Only explicit purchase cancellation can show the offer.
- Claiming grants exactly 10 credits once per campaign.
- A failed grant cannot silently dismiss the offer.
- The credit balance updates immediately after success.
- The review request is delayed until a later successful recognition.
- No UI or analytics imply that credits depend on a review.
- English copy is complete in the string catalog.
- Unit and UI tests cover eligibility, idempotency, and review timing.
- App Store review notes explain that the 10-credit recovery grant is unconditional and independent of the system review request.

## 17. App Review Notes

Suggested English note for App Review:

> After a user cancels an optional purchase, the app may offer a one-time package of 10 complimentary identifications. The grant is unconditional and does not require a rating, review, or other App Store action. A standard StoreKit review request may be made later, only after the user successfully completes an identification. The app does not detect or reward review completion.
