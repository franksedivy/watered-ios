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

The shared [test plan](../Watered/Watered.xctestplan) includes unit and UI targets but excludes `WateredUITestsLaunchTests`. The Stats UI test `testSavedImperialDrinkReformatsInMillilitres` is re-enabled with #104; #138 still requires runtime evidence before closure. “Configured suite passed” must not imply excluded or skipped tests ran. New pushes cancel older runs on the same branch; report cancellation separately from a test failure.

UI tests use `-uiTestingInMemory` with synthetic data. Debug failure hooks include `-uiTestingFailFirstDrinkSave` and `-uiTestingFailFirstDisplayUnitSave`, which require isolated storage. Release builds ignore test arguments. Do not use personal drink history or Health data for automated tests.

## Manual review menu

Select scenarios relevant to the change; use the full applicable set during release verification.

- Log a drink; confirm amount, preparation, Today totals and saved details agree. Relaunch to verify persistence using a disposable persistent store.
- Fail a save and retry: preserve the user's selection, prevent duplicate entries and avoid false success feedback.
- Repeat a supported recent drink; check fresh identity/time and current estimates. Check unsupported or retired definitions remain excluded from shortcuts while saved history stays readable.
- Change display units and a Profile goal; dismiss and reopen. Verify unchanged goals do not add history, and failed persistence does not change applied values.
- Delete a drink; check history and totals. Exercise any delete-all flow only on disposable data with explicit confirmation.
- Check affected layouts with large Dynamic Type, VoiceOver, Reduce Motion, sheet dragging and relevant light/dark appearances.
- Check calendar-day boundaries and timezone-sensitive behaviour when changing date filtering.

For Add Drink prototype work under [#104](https://github.com/franksedivy/watered-ios/issues/104), reconcile UI tests with the agreed interaction before calling it release-ready. See [Add Drink interaction](Add-Drink-Category-Prototype.md) for the current behaviour and remaining manual checks.

## Report evidence precisely

Record revision, command or CI run, environment, checks included, result and untested areas in the PR. Separate build success, focused tests, configured suite results and manual device review. A skipped test, cancelled run or unavailable toolchain is not a pass. Once relevant checks pass, repeat only for new changes or unresolved concerns.
