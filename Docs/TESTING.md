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
3. Once #111 supplies the explicit action (or using a temporary contributor-owned
   debug harness calling `requestAuthorizationFromUserAction()`), check the sheet
   contains only water, caffeine and alcohol writes, no reads, with the approved copy.
   Check all-denied and mixed grants; completion must not imply authorization.
4. Change grants in Health/Settings and return to Watered: per-type status refreshes
   without another prompt. Check restrictions where a controlled device supports them.
5. Record revision, device/iOS, signing evidence and each outcome. These steps are a
   plan, not completed device evidence. Sample writes and lifecycle tests belong to #112.

API references checked for this boundary: [authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
and [capability configuration](https://developer.apple.com/documentation/xcode/configuring-healthkit-access).
Both usage descriptions are configured, as Apple instructs; the read description states
that Watered does not read Health data and the request read set is always empty.
