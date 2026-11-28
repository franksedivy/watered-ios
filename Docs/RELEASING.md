# Releasing Watered

Release checklist agreed on 6 November 2026. Signing/upload automation and the detailed TestFlight procedure remain to be established; adopting this checklist does not implement them.

## Scope and candidate

- [ ] Confirm the milestone's committed scope, deferred work and unresolved blockers in GitHub.
- [ ] Check the actual candidate branch and revision; do not infer merge or launch status from chat summaries.
- [ ] Resolve prototype decisions and documented verification gaps. Existing prototypes are not automatically release requirements.
- [ ] Confirm supported OS versions and devices deliberately. Review any deployment-target increase and new API availability against that support decision.
- [ ] Review data compatibility for the candidate, especially snapshot-backed history. Development-data reset instructions are not a production migration plan.
- [ ] Confirm the release destination: internal checkpoint, TestFlight or App Store. Distribution-specific tasks apply only to the chosen destination.

## Verify

- [ ] Run the configured unit/UI plan on the candidate revision and inspect results. Record exclusions, failures and any explicitly accepted limitations.
- [ ] Complete applicable [manual/device checks](TESTING.md), including persistence after relaunch and affected accessibility flows.
- [ ] Confirm the Release build configuration and privacy behaviour: no accidental Debug hooks or production analytics collection.
- [ ] For HealthKit export, verify the implemented capability, permission text, export behaviour and device evidence against the candidate. Existing implementation and focused checks do not replace final release verification.
- [ ] Attach exact evidence to the release PR or checklist; distinguish simulator and physical-device coverage.

## Prepare and approve

- [ ] Agree the version, build number and tag convention. Inspect the app target's settings rather than confusing test-target versions with the product version.
- [ ] Set the marketing version deliberately in the app target, then verify the final candidate. Builds increment automatically as described below; neither a version change nor a build authorizes publication.
- [ ] Draft release notes from completed, verified changes. Link related issues/PRs and describe known limitations.
- [ ] Update README status and affected docs to reflect the candidate accurately.
- [ ] Obtain explicit agreement for the merge and for the intended publication/distribution action. Review approval alone does not imply both.

## Publish and confirm

- [ ] Merge only the agreed candidate and identify the resulting revision.
- [ ] Create the agreed tag/GitHub release against the intended revision when authorized.
- [ ] For TestFlight/App Store, confirm signing account, destination and responsible person before archiving/uploading. Record the build identifier and submission result.
- [ ] Verify the resulting release or build is actually available. Uploaded, processing, submitted, approved and live are different states.
- [ ] Close the milestone only when its completion criteria are satisfied; move deferred issues explicitly.
- [ ] Capture remaining follow-ups and archive the release chats after the outcome is recorded.

## Follow up after release

- [ ] Assign an owner and review point for available crash reports and user-reported problems after distribution.
- [ ] Record affected version/build, reproduction evidence and impact in follow-up issues. Passing pre-release tests does not rule out failures in use.
- [ ] Collect only diagnostics needed to investigate; exclude personal drink histories and Health data. Adding a diagnostics provider requires a separate privacy and collection decision.
- [ ] Turn confirmed regressions into focused fixes and appropriate regression checks. Absence of reports is not proof of a crash-free release.

## Still to settle

Version/tag naming, signing and upload ownership, supported physical-device matrix, beta acceptance criteria, App Store metadata responsibilities and recovery procedure need agreement before the first applicable distribution. A Git revert does not necessarily undo persisted-data changes or a distributed binary; define recovery for the actual change.

## Build identifiers

Each Debug or Release app build (including an incremental build or archive)
runs the **Build Version → Allocate build number** Xcode script. It increments
the repository's `BuildNumber.txt`, initially `0`, so the first build is `1`.
Include the updated counter in your next commit: another checkout continues
from that committed number. Routine builds change this small file, not the
tracked Xcode project. Marketing version remains a deliberate target setting.

The script writes a generated header in DerivedData. Xcode preprocesses the
app's Info.plist with that number before signing; it never patches a signed
bundle. App metadata lives in the explicit `Watered/Watered/Info.plist` so
automatic plist generation cannot override the scripted number.
The shared dependency runs once per build, even when tests depend on
the app. Running an already-built app or `test-without-building` does not allocate.
Allocation failures stop the build; failed builds may consume numbers. A small
file lock prevents simultaneous builds in this checkout reusing a number.
Only this allocation target disables Xcode's script sandbox, because it must
update the source-controlled counter; other targets retain their settings.

This is intentionally a simple development counter, as agreed for #196.
Separate machines, branches and fresh CI checkouts can reuse numbers until an
updated counter is committed and shared. CI uses the same script but does not
push counter changes. Resolve counter conflicts by retaining the highest used
number. Global uniqueness/distribution numbering is deferred until closer to
release. The widget does not exist yet: when #190 adds it, make it depend on
**Build Version** and consume the same generated header and marketing version,
rather than adding a second allocator.

Testers can find **Version … (build …)** at the bottom of Profile. Record it
alongside source revision (and any uncommitted changes), Debug/Release,
device and OS, including for #193/#194. Relaunching an installed artifact keeps
its identifier; rebuilding allocates a new one. The number alone does not
prove the source revision.

Headless script checks: `python3 -B Scripts/Build/test-build-number.py`.

### #196 implementation checks — 28 November 2026

Checked the uncommitted implementation on `feature/196-build-numbering`, based
on `cdfd44f86ef4a44fb041104d2ee03a1081d83b0a`, using Xcode 27.2 (27B52).
Four allocator checks and nine existing headless CI-helper checks passed.
Unsigned Debug simulator builds in `/tmp/watered-196-build` passed with
bundle identifiers **0.5 (build 5)** and **0.6 (build 6)** on an incremental
rebuild. The marketing version was edited separately during verification;
the allocator does not change it. Other Debug bundle metadata compared equal
before and after the explicit-plist migration.

An unsigned generic-iOS Release archive passed at `/tmp/watered-196.xcarchive`,
with bundle metadata **0.6 (build 7)**. Logs are `/tmp/watered-196-debug-final.log`,
`/tmp/watered-196-incremental-final.log` and `/tmp/watered-196-archive.log`.
Earlier integration attempts exposed missing header dependency and automatic
plist override problems, corrected before these checks; consumed numbers were
not reset. Plist syntax and whitespace checks passed.

No simulator test suite or hosted run was performed. Signed/device builds,
installed Profile text, relaunch/install behaviour, large text and spoken
VoiceOver presentation still need review. There is no widget target to verify.
