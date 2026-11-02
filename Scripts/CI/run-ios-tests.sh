#!/bin/bash
set -euo pipefail

# Keep this entry point off developer machines, including self-hosted local Macs.
if [[ "${GITHUB_ACTIONS:-}" != "true" || "${CI_RUNNER_ENVIRONMENT:-}" != "github-hosted" ]]; then
  printf '%s\n' 'iOS CI tests may run only on a GitHub-hosted runner.' >&2
  exit 64
fi

: "${RUNNER_TEMP:?Missing runner temporary directory}"
: "${DEVELOPER_DIR:?Missing pinned Xcode path}"
: "${XCODE_VERSION:?Missing pinned Xcode version}"
: "${IOS_SIMULATOR_RUNTIME:?Missing simulator runtime}"
: "${SIMULATOR_NAME:?Missing simulator name}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
results="$RUNNER_TEMP/watered-ios-ci"
mkdir -p "$results"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  printf 'Pinned Xcode is unavailable: %s\n' "$DEVELOPER_DIR" >&2
  exit 1
fi

xcodebuild -version | tee "$results/toolchain.log"
IFS= read -r selected_xcode < "$results/toolchain.log"
if [[ "$selected_xcode" != "Xcode $XCODE_VERSION" ]]; then
  printf 'Expected Xcode %s, got %s.\n' "$XCODE_VERSION" "$selected_xcode" >&2
  exit 1
fi

sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
printf '%s\n' "$sdk_version" > "$results/simulator-sdk.log"
if [[ "$sdk_version" != "$XCODE_VERSION" ]]; then
  printf 'Expected simulator SDK %s, got %s.\n' "$XCODE_VERSION" "$sdk_version" >&2
  exit 1
fi

xcrun simctl list devices available --json > "$results/simulator-devices.json"
simulator_id="$(jq -er --arg runtime "$IOS_SIMULATOR_RUNTIME" --arg name "$SIMULATOR_NAME" '
  (.devices[$runtime] // [])
  | map(select(.name == $name and .isAvailable == true))
  | if length == 1 then .[0].udid
    else error("Expected one available \($name) simulator for \($runtime)") end
' "$results/simulator-devices.json")"

printf 'Testing Watered on %s (%s, %s).\n' \
  "$SIMULATOR_NAME" "$IOS_SIMULATOR_RUNTIME" "$simulator_id"

# pipefail preserves a failing xcodebuild status while tee retains its output.
xcodebuild test \
  -project Watered/Watered.xcodeproj \
  -scheme Watered \
  -testPlan Watered \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -destination-timeout 120 \
  -derivedDataPath "$RUNNER_TEMP/watered-ios-derived" \
  -resultBundlePath "$results/Watered.xcresult" \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 180 \
  -maximum-test-execution-time-allowance 300 \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$results/xcodebuild.log"
