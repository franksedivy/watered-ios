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
- [ ] If the release adds HealthKit, separately verify the implemented capability, permission text, export behaviour and device checks. These are future gates, not implemented behaviour in this baseline.
- [ ] Attach exact evidence to the release PR or checklist; distinguish simulator and physical-device coverage.

## Prepare and approve

- [ ] Agree the version, build number and tag convention. Inspect the app target's settings rather than confusing test-target versions with the product version.
- [ ] Update version/build settings as needed, then verify the final candidate if those changes affect the build. The inspected app baseline is marketing version `0.4`, build `1`; this is an observation, not a next-release recommendation.
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
