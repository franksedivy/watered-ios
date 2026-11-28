# Architecture

Source review: `c22a53b04e907db13b61958e744ec1cf977e7186`, 25 November 2026, including the merged #161 artwork presets and subsequent #172 contract comments. This implementation map does not establish distribution or release readiness.

## Structure

Paths below are relative to `Watered/Watered/`.

| Area | Responsibility and entry points |
| --- | --- |
| App | `App/WateredApp.swift` loads the catalogue, chooses analytics and configures SwiftData. `AppLaunchConfiguration` selects isolated Debug test storage. |
| App shell | `Views/WateredRootView.swift` forwards dependencies. `Views/WateredTabView.swift` coordinates navigation, sheets, persistence integration and applied settings. |
| Domain | `Models/` contains drink amounts, catalogue identities, immutable logged snapshots, goals and calculation inputs/results. |
| Catalogue | `Catalogue/` loads and validates bundled definitions, resolves preparations and calculates estimates for new entries. |
| Persistence | `Persistence/` contains SwiftData records, mapping and explicit save/delete operations. |
| Shared state | `Store/WateredStore.swift` holds loaded drink history, filters by calendar day and derives supported recent shortcuts. |
| Presentation | `HydrationTracker` calculates summaries; `ViewData/HydrationSummaryViewData.swift` formats them; SwiftUI views present them. |
| Analytics | Debug logs locally; Release uses `NoOpAnalyticsClient`. Neither current implementation sends network events. |

## Logging and reading drinks

A new selection is resolved against the current validated catalogue. `DrinkCatalogueSnapshot` captures identity, name, preparation, resolved estimates and catalogue/calculation versions. `DrinkEntry` requires this snapshot.

`DrinkSubmissionHandler` invokes persistence first. Only after saving succeeds does it update `WateredStore` and record a success event. Before staging a drink transaction, `DrinkEntryPersistence` saves unrelated pending edits; that preliminary save is outside the new transaction's rollback scope. The subsequent insertion/export-intent or deletion transaction rolls back on failure. Callers handle presentation and retry; they must not assume every thrown error rolled back all pending work.

Saved entries are restored from captured facts rather than recalculated using current definitions. Catalogue failure must not prevent history access. Removed or retired drinks remain readable from valid snapshots. Old enum-only development records are not automatically migrated or assigned invented estimates; see [Development Drink Data](Development-Drink-Data.md).

Recents include only current, supported definitions and preparations, deduplicated by identity, amount, unit and preparation. Repeating one resolves fresh estimates and creates a new entry. It does not copy the old snapshot as a new log.

## Hydration and units

`HydrationTracker` uses the entries supplied by its caller; calendar-day filtering is outside the tracker. Consumed volume and estimated hydration are different totals. Unknown hydration propagates as `nil`; zero and negative values remain meaningful. Breakdown grouping uses stable catalogue IDs and a deterministic latest name.

`HydrationSnapshot` is a derived summary, distinct from the immutable `DrinkCatalogueSnapshot` saved with a drink. View data formats the summary and applies display clamping without rewriting saved estimates. Volume conversion and formatting live in `Utilities/`.
`ViewData/AddDrinkVolumeSelection` retains an exact amount and source unit while
preparing the Add Drink wheel in the applied Profile unit. Converted non-preset
values are included without snapping; only a changed wheel selection replaces the
amount. Session drafts and submission retain the captured value/unit rather than
rounded display text. Recent labels use the same volume formatter with the applied
unit; shortcut identity and repetition retain the original amount and preparation.

## Widget summary boundary (#189)

`WidgetSummary/WidgetSummaryDerivation.swift` derives a daily summary from supplied
visible committed entries and applied `AppSettings`, using the same Calendar day
selection as `WateredStore` and the existing `HydrationTracker` snapshot. It never
consults the current catalogue, reads persistence, or changes goal history. Callers
must supply committed state, excluding drafts and deleted rows; publication wiring
is separate work.

`WidgetSummary.swift` defines Codable JSON v1 and a bounded codec. All eleven keys
are required, with Unix-second timestamps, calendar/time-zone identifiers, durable
Profile unit IDs and canonical millilitres. Unknown hydration encodes three explicit
nulls; unavailable data is a separate result. Known negative and over-goal values
remain unclamped. Arithmetic uses absolute/relative tolerance `1e-9`; remaining is
nonnegative. Validation requires the current Calendar day and time zone, generation
within that day and no later than the read clock. There is no same-day age expiry.
Unsupported schemas, extra/missing fields, malformed values and payloads over 64 KiB
are unavailable. Future storage readers must also bound file reads before allocation.
The payload excludes history, liquid totals and Health data. There is no WidgetKit,
App Group I/O, publication or rendering integration in this boundary.

## Settings and goal history

SwiftData stores drink entries, app settings and goal-change records. `AppSettingsPersistence.loadOrCreate` creates first-run settings and a baseline goal record together. Profile edits use a draft; dismissal saves the final changed goal once. Unchanged goals create no additional record. A failed goal save preserves the applied goal.

Display-unit persistence is separate from goal changes. Failed saves preserve the applied
unit used by fresh/restored Add Drink forms and the recent menu. Settings `updatedAt` is not the timestamp of a specific goal change. Retaining goal history does not by itself prove that every historical screen applies historical goals.

## Catalogue and current UI boundary

`ViewData/AddDrinkPreparationPresentation.swift` owns persistent preparation rows
and their category sheet heights. Coffee retains caffeine and shots rows; Tea and
Soft Drinks retain one caffeine row. Alcohol retains its Non-alcoholic row and
ABV controls, with the toggle disabled where the catalogue offers no alternative.
Catalogue capabilities determine availability
and the supported alternative. Disabled rows are presentation placeholders, not
new preparations or changes to caffeine estimates. The view retains selection,
draft and submission responsibilities.

`ViewData/AddDrinkArtworkSize.swift` owns Add Drink's local artwork presentation
hints and small/medium/large bounds (54/64/74 pt). Espresso selects small and
Sparkling wine medium; absent hints resolve to large. The row retains its fixed
88 × 88 pt cell. These hints do not enter catalogue definitions, preparations or
saved snapshots, so catalogue schema/content/manifest versions are unchanged.

The manifest names category JSON resources explicitly; the loader validates the assembled catalogue and fails rather than returning a partial result. See [Drink Catalogue Files](Drink-Catalogue-Files.md) for formats and content maintenance. The catalogue contains 60 definitions: four Water, seven Coffee, ten Tea, four Juices, six Soft Drinks, three Wellness, four Sports & Energy, twelve Milk & Alternatives, eight Alcohol and two Other, under content development-25 / schema 6. Alcohol uses discrete ABV choices and optional non-alcoholic preparations; calculation version 3 gives alcoholic preparations zero goal credit. Optional saved preparation/ABV fields preserve older rows without recalculating history. The four Water, seven Coffee, ten Tea, four Juice, six Soft Drink, three Wellness, four Sports & Energy and twelve Milk & Alternatives definitions have reviewed water-content fractions; the eight Alcohol definitions use reviewed strength tables and both Other definitions have reviewed fixed fractions. Coffee water fractions remain fixed across regular/decaf and shot counts. Calculation version 5 captures a separate optional water amount in snapshots and persistence; existing rows remain unknown. HealthKit mapping remains separate.

The merged #104 interaction work provides bundled drink artwork, category defaults, preparation controls, a long-press recent menu and a session-only unsaved draft owned by the app shell. See [Add Drink interaction](Add-Drink-Category-Prototype.md). Persistent last-used category choices remain unfinished.

Widgets, a Watch app, iCloud sync and production analytics are outside the implemented baseline described here. HealthKit's implemented boundaries are described below. Keep proposed systems separate from this implementation map until code exists.

## Maintaining this map

Update this document when responsibilities or data contracts change. Record significant rationale separately using a [decision record](decisions/TEMPLATE.md), linking any relevant historical entry in the wiki Decision Log. Do not turn this file into a release backlog.

Alcohol water uses schema 6 reviewed tables for every supported ABV and a separate
non-alcoholic fraction where offered. Calculation version 5 resolves the selected
preparation before saving water; no historical amounts are recalculated.


`HealthExport/AlcoholExportQuantity.swift` is the pure saved-volume/ABV conversion
for the approved 14 g standard-drink convention (`alcohol-14g-v1`). It returns
positive, known-zero, unknown or invalid results without catalogue lookup, HealthKit
calls or changes to saved entries. Sample dates, permissions and durable export
policy/version context remain integration responsibilities. See the mapping decision.

## HealthKit authorization boundary

`WateredApp` retains `HealthAuthorizationController` and one injected `HealthKitClient`.
`AppleHealthKitClient` owns a long-lived system store, checks availability before access,
and requests only water, caffeine and alcohol write permissions with an empty read set.
The controller refreshes per-type status on foreground entry without prompting; future
operations read the client’s current authorization rather than cached presentation state.
Only `requestAuthorizationFromUserAction()` may request permission. Profile’s Apple Health
screen invokes it through Review permissions in Debug and Release and displays per-type states/errors.
Its independent sync switch persists the app preference through the existing coordinator. The screen-opened and review-tapped
analytics events carry no properties; Debug logs locally and Release discards them.
Profile also supplies analytics to the coordinator's preference action: a committed
off-to-on transition emits `apple_health_sync_enabled`, with no properties. Failed
saves, already-on requests, disabling and operational/harness calls do not emit it.
Completion refreshes grants rather than assuming them.
Denied/revoked and not-determined states are per type; restricted/unavailable request
errors are separate from grants because the platform does not expose a distinct
per-type restricted authorization status. Errors retain no raw Health data or descriptions.

Permission grants do not enable sync. The #109 setting, eligibility
transaction, upload executor and deletion cleanup are described below.
Local saving remains independent. Isolated tests and app previews use
`FakeHealthKitClient`; standalone view previews do not construct a Health store.

## Frozen HealthKit sample mapping (#108)

`HealthExport/HealthSampleMapping.swift` maps saved water ml, caffeine mg and the
reviewed fractional alcohol count independently. The caller must supply the types
eligible at entry creation; the mapper never consults authorization or infers consent
from timestamps. Unknown, known zero, ineligible and invalid outcomes are distinct.
Invalid dates/consumed volume reject eligible types; individual quantity failures
leave other types available. Hydration credit and the current catalogue are unused.

`HealthSampleSpecification` freezes quantities, units, loggedAt, manual provenance,
catalogue/calculation context, export policy `health-export-v1`, alcohol policy where
applicable, and a namespaced entry-UUID/type identity with sync version 1. Its Codable
representation is persisted by #109's pending-work storage.
Retries must reuse that payload instead of mapping again. Policy versions are separate
from HealthKit sync version, which must not increase on retry.

`HealthKit/HealthSampleFactory.swift` validates the frozen specification and constructs
an HKQuantitySample with equal loggedAt start/end dates, the reviewed units, manual
metadata and sync identity/version. It rejects unsupported policies rather than
reinterpreting them. It does not open a Health store or perform writes. #109 owns
atomic eligibility capture, persistence, execution and retries; actual same-version
write behavior still needs controlled-device verification under #112.

## Durable Health export (#109)

`PersistentHealthSyncPreference` is device-local and defaults to disabled. Its
`enabledAt` records the latest enablement; it is not a history/backfill query.
`HealthExportPersistence.capture` reads the committed preference and current
per-type grants synchronously in the new drink transaction. Both form and Recents
use that boundary. Existing entries, disabled gaps and newly granted types are
never scanned into the queue. Unknown/zero quantities omit work; invalid quantities
persist independent invalid records. Backdated new entries keep `loggedAt`.

`PersistentHealthExport` stores a frozen Codable specification, stable per-type
identity, policy/sync versions, desired operation, status, attempt count, retry date,
sanitized failure and possible-write flag. The app adds these entities and optional
`PersistentDrinkEntry.deletedAt` without resetting storage. No CloudKit is enabled;
these leases, acknowledgements and preferences must not become cross-device state.

One app-lifetime `HealthExportCoordinator` serializes writes on MainActor, persists
in-flight intent before I/O and acknowledges each type afterward. Each attempt and
acknowledgement reads a fresh context to observe preference/deletion commits without
saving or rolling back unrelated UI edits. Uncertain in-flight work retries its
original payload, identity and sync version 1. Acknowledged work is never resent or
queried for existence, including after manual deletion in Health.

Temporary failures retry with equal jitter: 15–30 seconds initially, doubling to
an upper limit of six hours. Due work runs while foreground execution is available,
on reopening/foregrounding, after a committed submission or enablement, and through
`retryNow()`. Permission-blocked work waits for a later trigger and restored grants;
invalid work stops. No retry requests permissions. Disabling prevents new upload
starts while allowing an in-flight result to persist. Local save/state/analytics
success does not await Health. Raw Health errors and payloads are not logged.

The deletion boundary cancels never-started work and atomically hides possibly-written
drinks while retaining their details and per-type cleanup intent. The same serialized
worker settles late uploads before cleanup, including when exports are disabled.
`HealthDeletionTarget` carries only the stable entry/type identity; cleanup does not
need an intact upload payload, current catalogue or returned sample UUID.
`AppleHealthKitClient.delete` constrains `deleteObjects` by quantity type, default app
source and sync identifier. It performs no read query and requests no new permissions.
A successful zero-match result resolves cleanup; denial retains blocked work indefinitely.

Each type persists its own deletion acknowledgement. `purgeCompletedDeletions` removes
the hidden drink and its records only when every required type has succeeded, in the
same transaction as the final acknowledgement. A failed acknowledgement leaves durable
in-flight work for the same constrained retry. The executor also recovers completed
but unpurged tombstones. Debug reset uses the same atomic transaction for its selected
visible history, preserving older cleanup, settings and goal history. Profile displays
pending/blocked cleanup feedback. Individual/reset confirmations mention Health only
when the selected drinks have eligible or possibly-written records, independently of
the current switch. Queued work is included because it can finish while confirmation
is open. Physical ownership and lifecycle checks remain required.

`HealthSyncView` shows the persisted switch and final Privacy & information row
while disabled. Enabling reveals per-type permissions and an Export status link. `HealthExportStatusView` owns the
per-type summaries and Retry now on that subpage. The main view’s bottom
Privacy & information row always opens `HealthSyncInformationView`, which presents explanatory/privacy prose without duplicate controls.
Pending cleanup stays actionable on the main screen even while uploads are off. Permission labels
retain their text and accessibility values alongside green Allowed and amber Not allowed.
Fresh contexts refresh the preference and value summaries after worker activity and
foreground entry; failed reads disable preference edits, and failed writes preserve
the previous choice. `HealthExportStatus` excludes deletion records from upload counts
and never infers current Health contents from acknowledged writes. Permission recovery
remains an explicit action, separate from enablement and retries. New stores remain disabled.
See [HealthKit privacy review](HealthKit-Privacy.md) for user-facing and store wording.

Same-version HealthKit deduplication requires #112's controlled-device evidence;
fake/simulator tests establish the local protocol only. The accepted limitation
remains: if a successful write is unacknowledged and the user removes it in Health,
recovery may recreate it. No exactly-once or background-completion guarantee.

### Debug verification harness

`Debug/DebugHealthExportHarness.swift` provides in-memory, one-shot failure-before-I/O
and success-before-acknowledgement pause hooks for both uploads and cleanup. `DebugHealthExportView` exposes the
normal persisted switch, Retry now and local record inspection in Profile. It never
requeues acknowledged samples, mutates frozen payloads, reads Health history or emits
analytics. The hook calls and both Debug types are excluded from Release compilation.
The persisted export preference retains its ordinary cross-launch behavior; disable
it when device testing finishes. See [Testing](TESTING.md#debug-only-device-harness-109-112).

### Isolated Health UI fixtures (#111)

`DebugHealthUITestClient` is selected only by an explicitly named Health scenario
with isolated in-memory Debug storage. It seeds synthetic pending/failed/blocked
work before the coordinator starts and supplies fake permission/write/delete results.
The screen still uses the real preference transaction and serialized executor.
No fixture opens a Health store; the type and seeding hook are absent from Release.
Permission rows expose a quantity label plus a separate accessibility status value.
See [the focused local UI exception](TESTING.md#focused-local-ui-execution-exception)
for the authorized local run; CI continues to exclude UI tests.
