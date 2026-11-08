# Architecture

Source baseline: main through `f47869c`, with the #104 interaction changes reviewed on 6 November 2026. This implementation map does not establish distribution or release readiness.

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

`DrinkSubmissionHandler` invokes persistence first. Only after saving succeeds does it update `WateredStore` and record a success event. `DrinkEntryPersistence` rolls back failed saves; callers handle presentation and retry. Rollback can affect pending changes in the supplied context, so transaction boundaries matter.

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

## Settings and goal history

SwiftData stores drink entries, app settings and goal-change records. `AppSettingsPersistence.loadOrCreate` creates first-run settings and a baseline goal record together. Profile edits use a draft; dismissal saves the final changed goal once. Unchanged goals create no additional record. A failed goal save preserves the applied goal.

Display-unit persistence is separate from goal changes. Failed saves preserve the applied
unit used by fresh/restored Add Drink forms and the recent menu. Settings `updatedAt` is not the timestamp of a specific goal change. Retaining goal history does not by itself prove that every historical screen applies historical goals.

## Catalogue and current UI boundary

The manifest names category JSON resources explicitly; the loader validates the assembled catalogue and fails rather than returning a partial result. See [Drink Catalogue Files](Drink-Catalogue-Files.md) for formats and content maintenance. The current branch contains four Water, seven Coffee and four plain Tea definitions under content development-6 / schema 3; the wider catalogue remains unfinished.

The #104 branch adds bundled drink artwork, category defaults, preparation controls, a long-press recent menu and a session-only unsaved draft owned by the app shell. See [Add Drink interaction](Add-Drink-Category-Prototype.md). Persistent last-used category choices remain unfinished.

HealthKit export, widgets, a Watch app, iCloud sync and production analytics are outside the implemented baseline described here. Keep proposed systems separate from this implementation map until code exists.

## Maintaining this map

Update this document when responsibilities or data contracts change. Record significant rationale separately using a [decision record](decisions/TEMPLATE.md), linking any relevant historical entry in the wiki Decision Log. Do not turn this file into a release backlog.
