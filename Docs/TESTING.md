# Testing

Testing guidance agreed on 6 November 2026. Runner behaviour and test-plan exclusions describe the inspected configuration, not a claim that tests currently pass.

## Choose checks for the change

| Change | Useful evidence |
| --- | --- |
| Copy or documentation | Diff review, local link check and whitespace check |
| Hydration, units or catalogue rules | Focused domain tests for changed behaviour and edge cases |
| Persistence or snapshots | Round-trip mapping, saved-fact preservation, failure rollback and no false success state |
| Profile settings | Changed/unchanged goals, commit on dismissal, unit independence and failure handling |
| Add Drink or history UI | Relevant UI tests plus visual/device review of affected interactions |
| CI helper/configuration | Local stub-based helper checks plus a hosted run |
| Release candidate | Configured unit/UI plan and documented manual/device checks for the candidate revision |

Domain tests use Swift Testing; UI tests use XCTest. Prefer observable behaviours over tests that mirror implementation. Use deterministic dates, identities and synthetic catalogue fixtures where relevant.

## Running and inspecting tests

For contributor-led local testing, open the shared `Watered` scheme in Xcode and use Product > Test or the test navigator for a focused selection. The selected runtime and toolchain should be recorded with the result.

Agent-run simulator suites default to hosted GitHub Actions. [Continuous Integration](Continuous-Integration.md) owns the pinned environment, execution limits, manual-run instructions and artifact retrieval. `Scripts/CI/run-ios-tests.sh` explicitly refuses local/self-hosted execution; do not bypass that guard.

The helper's stub-based checks are safe locally and do not run the app or a simulator:

```sh
bash Scripts/CI/test-run-ios-tests.sh
```

CI temporarily runs only `WateredTests`, as agreed on 9 November 2026. All UI tests
are excluded from hosted execution; they remain available locally. Reintroduce them
in focused increments as the app matures. A green CI check is a unit-suite pass,
not a full unit/UI-suite pass, and does not close unresolved UI issues (#155/#138).

The shared [test plan](../Watered/Watered.xctestplan) includes unit and UI targets but excludes `WateredUITestsLaunchTests`. The Stats UI test `testSavedImperialDrinkReformatsInMillilitres` is re-enabled with #104; #138 still requires runtime evidence before closure. “Configured suite passed” must not imply excluded or skipped tests ran. New pushes cancel older runs on the same branch; report cancellation separately from a test failure.

UI tests use `-uiTestingInMemory` with synthetic data. Debug failure hooks include `-uiTestingFailFirstDrinkSave` and `-uiTestingFailFirstDisplayUnitSave`, which require isolated storage. Release builds ignore test arguments. Do not use personal drink history or Health data for automated tests.

## Manual review menu

Select scenarios relevant to the change; use the full applicable set during release verification.

- Log a drink; confirm amount, preparation, Today totals and saved details agree. Relaunch to verify persistence using a disposable persistent store.
- Fail a save and retry: preserve the user's selection, prevent duplicate entries and avoid false success feedback.
- Repeat a supported recent drink; check fresh identity/time and current estimates. Check unsupported or retired definitions remain excluded from shortcuts while saved history stays readable.
- Restore a 500 ml unsaved coffee with decaf and three shots after switching Profile
  to US fl oz: the wheel shows 16.907 US fl oz, with preparation retained. Cycle units
  and return to ml; saving/repeating must still produce 500 ml. Choosing 16 US fl oz
  deliberately changes the amount to approximately 473.176 ml.
- Check fresh Add Drink forms in all three units, converted recent-menu labels, and
  failed drink/unit saves. Failed unit persistence must leave form/menu units unchanged.
  `AddDrinkVolumeSelectionTests` and `RecentDrinkOptionTests` cover all unit pairs;
  Add Drink UI suites cover the picker, preparation, saved amounts and long-press menu.
- Change display units and a Profile goal; dismiss and reopen. Verify unchanged goals do not add history, and failed persistence does not change applied values.
- Delete a drink; check history and totals. Exercise any delete-all flow only on disposable data with explicit confirmation.
- Check affected layouts with large Dynamic Type, VoiceOver, Reduce Motion, sheet dragging and relevant light/dark appearances.
- Check calendar-day boundaries and timezone-sensitive behaviour when changing date filtering.

For Add Drink prototype work under [#104](https://github.com/franksedivy/watered-ios/issues/104), reconcile UI tests with the agreed interaction before calling it release-ready. See [Add Drink interaction](Add-Drink-Category-Prototype.md) for the current behaviour and remaining manual checks.

## Report evidence precisely

Record revision, command or CI run, environment, checks included, result and untested areas in the PR. Separate build success, focused tests, configured suite results and manual device review. A skipped test, cancelled run or unavailable toolchain is not a pass. Once relevant checks pass, repeat only for new changes or unresolved concerns.

## HealthKit authorization (#107)

`HealthAuthorizationTests` uses a fake system-store seam and synthetic states; it
checks the exact three-type write scope, empty read set, mixed grants, availability,
revocation refresh, sanitized failures, overlapping actions and independent local logging.
It never opens a personal Health store. No simulator test proves device provisioning.

Controlled-device checks remain required before closing #107:

1. Enable HealthKit for App ID `com.franksedivy.wateredapp-ios` in the developer account.
   The target uses manual signing and `Frank's Dev Profile` for team `A5EYYY25C3`;
   regenerate/install that profile with the HealthKit entitlement, and confirm the
   signed app and embedded profile both contain `com.apple.developer.healthkit`.
   This change does not alter account configuration or signing identities.
2. On a controlled iOS 27 device, launch and save a synthetic drink: no permission
   sheet; local saving succeeds. Inspect both Debug and Release usage descriptions.
3. Use Profile → Apple Health permissions → Review permissions (available in Debug
   and Release; sync opt-in remains #111). This calls `requestAuthorizationFromUserAction()`. Check the sheet
   contains only water, caffeine and alcohol writes, no reads, with the approved copy.
   Check all-denied and mixed grants; completion must not imply authorization.
   Review permissions checks fresh status: any not-requested type takes priority
   and starts authorization; otherwise decided permissions (allowed or denied) show
   instructions for changing permissions in Health without repeating the system
   request. Unavailable or unknown states show explanatory feedback without requesting.
4. Change grants in Health/Settings and return to Watered: per-type status refreshes
   without another prompt. Check restrictions where a controlled device supports them.
5. Record revision, device/iOS, signing evidence and each outcome. These steps are a
   plan, not completed device evidence. Sample writes and lifecycle tests belong to #112.

API references checked for this boundary: [authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
and [capability configuration](https://developer.apple.com/documentation/xcode/configuring-healthkit-access).
Both usage descriptions are configured, as Apple instructs; the read description states
that Watered does not read Health data and the request read set is always empty.

### Device evidence — 22 November 2026

Frank performed these checks on an iPhone Air running iOS 27.2, using the working
checkout based on `fbb5e3f` plus the Debug Profile verification controls committed
with this record and the separate local marketing-version change to 0.5. Results
below are user-reported device observations, not agent-run UI tests.

- Xcode showed the HealthKit capability and both expected usage descriptions;
  Clinical Health Records and Background Delivery were unchecked. No signing errors
  were reported, and the app built, installed and launched successfully.
- Launch and local drink saving showed no permission prompt; the drink appeared in history.
- The explicit test action showed only Water, Caffeine and Alcoholic Beverages write
  permissions, with no read section.
- With all three denied, a repeated action showed no sheet; all three statuses were
  denied and the request error was nil. Another drink saved without prompting.
- Enabling only Water in Health refreshed Water to authorized while the other two
  stayed denied, without pressing the test button. Revoking Water refreshed it to denied.
- Enabling only Caffeine and Alcohol refreshed those two to authorized independently.
  Those states survived closing and reopening the app, with no prompt.
- Enabling all three refreshed all statuses to authorized. Repeating the explicit
  request showed no sheet, preserved all grants and reported no error.

Signing inspection followed the device checks, after checkpoint commit `e32efd8`.
Frank supplied command output from the existing `Debug-iphoneos/Watered.app` build;
the binary was not rebuilt or independently tied to a commit during this inspection.

- `codesign -d --entitlements :- <Watered.app>` showed
  `com.apple.developer.healthkit = true` in the signed app. Its application identifier
  was `A5EYYY25C3.com.franksedivy.wateredapp-ios` and team identifier was `A5EYYY25C3`.
- `security cms -D -i <Watered.app>/embedded.mobileprovision`, with its Entitlements
  dictionary extracted using `plutil`, showed HealthKit enabled and matching app/team
  identifiers. Both app and profile had `get-task-allow = true`, consistent with the
  inspected development build.
- The profile additionally permitted `com.apple.developer.healthkit.access` with
  `health-records` and `com.apple.developer.healthkit.background-delivery = true`.
  Neither entitlement appeared in the signed app. The broader profile permissions
  therefore do not establish that Watered enabled those capabilities.

These supplied outputs verify the HealthKit entitlement in both the signed Debug app
and its embedded provisioning profile. They are not Release signing evidence.

Still unverified: Release-build usage descriptions/behavior; device restrictions/unavailability;
accessibility review of the temporary controls. No Health samples were written by this
implementation. These observations do not close #107 or verify downstream export work.

Baseline automated evidence remains [286 unit tests on fbb5e3f](https://github.com/franksedivy/watered-ios/actions/runs/45018482759)
(Xcode 27.1, iPhone Air simulator/iOS 27.0), including HealthAuthorizationTests. That
run predates the Profile verification controls and excludes UI tests.

Permission-screen follow-up checks (not covered by the device evidence above):
verify the Profile navigation row and detail screen in both Debug and Release;
opening the detail screen emits only `apple_health_permissions_opened`, once per
screen visit, and tapping Review permissions emits only
`apple_health_permissions_review_tapped`, including when guidance is shown.
Returning from Health or dismissing guidance must not count as a new screen visit.
Neither event carries properties. Debug logs locally; Release uses NoOpAnalyticsClient.

## HealthKit sample mapping (#108)

`HealthSampleMappingTests` covers reviewed water/latte/beer/cocktail examples,
regular/decaf/zero shots, bounded alcohol, all volume units, unknown versus zero,
independent invalid quantities, invalid dates/volumes, all eight eligible-type sets,
frozen payload serialization and stable per-entry/type identity. Platform-boundary
assertions check HealthKit types, units, dates and manual/sync metadata without opening
a Health store. Corrupt payloads and unsupported policies fail construction.

These tests do not prove durable intent capture, scheduling, writes, deduplication or
physical-device behavior. Those remain #109/#112. No simulator suite is run locally.

## Durable Health export (#109)

`HealthExportTests` uses synthetic entries, temporary SwiftData stores and injected
clients. Coverage includes atomic entry/intent rollback, form/Recents analytics
isolation, duplicate local identity, independent results, disabled gaps, backdating,
permission restoration without backfill/prompts, due/manual retries, bounded jitter,
corrupt/invalid payloads, pre-I/O and post-I/O/pre-acknowledgement failures, frozen
recovery, concurrent triggers, disable/delete during suspended writes, deletion
rollback, disk reopening, acknowledged non-resend and sanitized platform errors.
The additive-entity test opens an existing drink-only store with the expanded schema;
it does not independently prove migration of every historical schema version.

No automated test writes into a real Health store or proves same-version platform
deduplication. Before accepting the duplicate-prevention criterion in #109/#112,
use disposable data on a controlled physical device and record revision/device/iOS:

1. Enable sync through the forthcoming #111 controls; verify independent sample
   quantities/dates/source and stable sync metadata for backdated new entries.
2. Repeat a frozen write with the same identity/version, including stopping after
   Health save but before local acknowledgement. Inspect actual sample counts.
3. Delete an acknowledged sample in Health and reopen/re-enable/retry: it must
   remain absent. Separately demonstrate the accepted unacknowledged-write limitation.
4. Verify denial/revocation, partial grants, disabled gaps and disable during I/O;
   local logging/dismissal and once-per-submission analytics must remain independent.
5. Complete #110/#111/#112 cleanup, status/copy, UI and device scenarios before
   treating optional export as release-ready. Retained delete intent is not cleanup.
