# Continuous Integration

## Runs

The `iOS CI` GitHub Actions workflow runs on every branch push. Same-repository
pull requests show the check associated with their pushed head commit; there is
no separate PR trigger to duplicate the tests. External fork PRs are not
automatically tested upstream by this initial push-only configuration.

After the workflow reaches `main`, manual runs are available under **Actions >
iOS CI > Run workflow**. Choose a branch when starting a manual run. Existing
runs can also be rerun from their Actions page.

A newer run cancels an older run for the same branch. Jobs have a 45-minute limit,
the test step has a 40-minute limit, and individual test timeouts are bounded.

## Test scope

As agreed on 9 November 2026, CI executes only `WateredTests` using
`-only-testing:WateredTests`. All UI tests are temporarily excluded from hosted
execution during active development. Their source and shared local test plan remain
intact for contributor-run checks. Reintroduce UI coverage incrementally as the app
matures, through explicit changes to this selection and its helper checks.

A green CI run proves unit-test coverage only; it does not resolve the outstanding
UI failures tracked in #155/#138 or replace manual/device review.

## Environment

- GitHub-hosted `xcode-27` arm64 image, currently a public preview.
- Stable Xcode `27.1`, selected through `DEVELOPER_DIR`; not the 27.2 release candidate.
- One available iPhone Air running iOS `27.0`.
- Shared `Watered` scheme and `Watered.xctestplan`, including its intentional exclusions.
- Simulator tests without distribution signing, provisioning or personal Apple credentials.

The helper checks the pinned Xcode, SDK and simulator before testing. Missing
tooling fails explicitly rather than silently switching toolchains or runtimes.
The application's minimum deployment target is unchanged.

The test entry point refuses local and self-hosted execution. It must not be used
to start tests on a developer's Mac. Its headless helper checks use stub Apple
commands and can safely run locally:

```sh
bash Scripts/CI/test-run-ios-tests.sh
```

UI tests use the existing isolated-storage launch arguments and synthetic data.
CI does not inspect personal drink stores or write to personal Health data.
Physical-device behaviour and visual review remain separate checks.

## Results

Open the workflow run from the PR check or repository Actions page. The
`ios-tests-<run-id>-<attempt>` artifact contains toolchain/simulator diagnostics,
the build/test log and `Watered.xcresult` when Xcode produced a result bundle.
Download and unzip it, then open the result bundle in a compatible Xcode to inspect
individual failures, screenshots and any UI-test recordings.

Artifacts are uploaded after successful or failed steps and retained for seven
days. An early infrastructure failure may have logs but no Xcode result bundle.
Cancellation or a hard job termination can prevent upload; GitHub's run logs
remain the first place to check those failures.

The repository is public and uses a standard runner, not a larger runner.
Standard hosted compute is free under GitHub's public-repository policy. Keep
retention bounded and review Actions usage if repository visibility or runner
selection changes. This workflow does not change billing settings.

## Maintenance

Update the runner label, Xcode path/version and simulator pin together after
checking the published runner inventory. Re-run the helper checks and verify a
remote test run. The checkout and upload actions are pinned to full release
commit SHAs; update the SHA and release comment together when reviewing upgrades.

The workflow uses read-only repository contents permission and does not persist
checkout credentials. It does not use privileged PR triggers, distribution
secrets, deployment or automatic merging. Making its check mandatory requires
a separate reviewed branch-protection change.

Before closing the setup ticket, verify a successful remote run and an isolated
intentional test failure, including result retention and the failing check.
Do not merge a failure-probe test into the application.

## References

- [Hosted runner inventory](https://github.com/actions/runner-images/blob/main/images/macos/xcode-27-arm64-Readme.md)
- [Preview image notice](https://github.com/actions/runner-images/issues/14404)
- [GitHub-hosted runner usage](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
