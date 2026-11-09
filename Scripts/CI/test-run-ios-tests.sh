#!/bin/bash
set -euo pipefail

# Every Apple tool used below is a stub. These checks never boot a simulator.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
temporary="$(mktemp -d "${TMPDIR:-/tmp}/watered-ci-checks.XXXXXX")"
trap 'rm -rf "$temporary"' EXIT
mkdir -p "$temporary/bin" "$temporary/Xcode.app/Contents/Developer"

cat > "$temporary/bin/xcodebuild" <<'STUB'
#!/bin/bash
set -euo pipefail
if [[ "${1:-}" == "-version" ]]; then
  printf 'Xcode %s\nBuild version fixture\n' "${STUB_XCODE_VERSION:-27.1}"
  exit 0
fi
printf '%s\n' "$@" > "$STUB_XCODE_ARGS"
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "-resultBundlePath" ]]; then
    shift
    mkdir -p "$1"
    printf '%s\n' 'Synthetic test result' > "$1/fixture.txt"
  fi
  shift
done
printf '%s\n' 'Synthetic xcodebuild test output'
exit "${STUB_EXIT:-0}"
STUB

cat > "$temporary/bin/xcrun" <<'STUB'
#!/bin/bash
set -euo pipefail
case "$*" in
  '--sdk iphonesimulator --show-sdk-version')
    printf '%s\n' "${STUB_SDK_VERSION:-27.1}"
    ;;
  'simctl list devices available --json')
    jq -n --arg name "${STUB_DEVICE_NAME:-iPhone Air}" \
      --argjson available "${STUB_AVAILABLE:-true}" '
      {devices: {"com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
        {name: $name, isAvailable: $available,
         udid: "11111111-1111-1111-1111-111111111111"}
      ]}}'
    ;;
  *) printf 'Unexpected xcrun invocation: %s\n' "$*" >&2; exit 99 ;;
esac
STUB
chmod +x "$temporary/bin/xcodebuild" "$temporary/bin/xcrun"

run_case() {
  local name="$1"
  shift
  CASE_ROOT="$temporary/$name"
  mkdir -p "$CASE_ROOT"
  set +e
  env PATH="$temporary/bin:$PATH" GITHUB_ACTIONS=true \
    CI_RUNNER_ENVIRONMENT=github-hosted RUNNER_TEMP="$CASE_ROOT" \
    DEVELOPER_DIR="$temporary/Xcode.app/Contents/Developer" XCODE_VERSION=27.1 \
    IOS_SIMULATOR_RUNTIME=com.apple.CoreSimulator.SimRuntime.iOS-27-0 \
    SIMULATOR_NAME='iPhone Air' STUB_XCODE_ARGS="$CASE_ROOT/arguments.txt" \
    STUB_EXIT=0 STUB_XCODE_VERSION=27.1 STUB_SDK_VERSION=27.1 \
    STUB_DEVICE_NAME='iPhone Air' STUB_AVAILABLE=true \
    "$@" bash "$repo_root/Scripts/CI/run-ios-tests.sh" > "$CASE_ROOT/output.log" 2>&1
  CASE_STATUS=$?
  set -e
}

assert_status() {
  if [[ "$CASE_STATUS" -ne "$1" ]]; then
    printf 'Expected status %s, got %s.\n' "$1" "$CASE_STATUS" >&2
    cat "$CASE_ROOT/output.log" >&2
    exit 1
  fi
}

run_case success
assert_status 0
grep -Fxq -- '-only-testing:WateredTests' "$CASE_ROOT/arguments.txt"
test "$(grep -c -- '^-only-testing:' "$CASE_ROOT/arguments.txt")" -eq 1
grep -Fq -- '-testPlan' "$CASE_ROOT/arguments.txt"
grep -Fxq -- 'Watered' "$CASE_ROOT/arguments.txt"
grep -Fxq -- 'CODE_SIGNING_ALLOWED=NO' "$CASE_ROOT/arguments.txt"
grep -Fxq -- 'platform=iOS Simulator,id=11111111-1111-1111-1111-111111111111' \
  "$CASE_ROOT/arguments.txt"

run_case failing-test STUB_EXIT=65
assert_status 65
test -f "$CASE_ROOT/watered-ios-ci/Watered.xcresult/fixture.txt"
grep -Fq 'Synthetic xcodebuild test output' "$CASE_ROOT/watered-ios-ci/xcodebuild.log"

run_case wrong-xcode STUB_XCODE_VERSION=26.6
assert_status 1
test ! -f "$CASE_ROOT/arguments.txt"

run_case wrong-sdk STUB_SDK_VERSION=26.6
assert_status 1
test ! -f "$CASE_ROOT/arguments.txt"

run_case missing-device STUB_DEVICE_NAME='Another iPhone'
test "$CASE_STATUS" -ne 0
test ! -f "$CASE_ROOT/arguments.txt"

run_case unavailable-device STUB_AVAILABLE=false
test "$CASE_STATUS" -ne 0
test ! -f "$CASE_ROOT/arguments.txt"

run_case local GITHUB_ACTIONS=false
assert_status 64
test ! -f "$CASE_ROOT/arguments.txt"

run_case self-hosted CI_RUNNER_ENVIRONMENT=self-hosted
assert_status 64
test ! -f "$CASE_ROOT/arguments.txt"

ruby -r yaml - "$repo_root/.github/workflows/ios.yml" <<'RUBY'
workflow = YAML.safe_load(File.read(ARGV.fetch(0)), aliases: false)
triggers = workflow['on'] || workflow[true]
abort 'Unexpected CI triggers' unless triggers.keys.sort == ['push', 'workflow_dispatch']
abort 'Branch pushes must be covered' unless triggers['push']['branches'] == ['**']
abort 'Unexpected permissions' unless workflow['permissions'] == {'contents' => 'read'}
abort 'Missing cancellation' unless workflow['concurrency']['cancel-in-progress'] == true
job = workflow.fetch('jobs').fetch('ios-tests')
abort 'Unexpected runner' unless job['runs-on'] == 'xcode-27'
abort 'Unbounded timeout' unless job['timeout-minutes'] == 45
abort 'Unexpected Xcode' unless job['env']['XCODE_VERSION'] == '27.1'
abort 'Runner context is unavailable in job env' if job['env'].key?('CI_RUNNER_ENVIRONMENT')
test_step = job['steps'].find { |step| step['name'] == 'Run unit tests' }
abort 'Missing hosted-runner guard' unless test_step['env']['CI_RUNNER_ENVIRONMENT'] == '${{ runner.environment }}'
actions = job['steps'].select { |step| step.key?('uses') }
abort 'Unexpected action dependency' unless actions.size == 2 && actions.all? { |step|
  step['uses'].match?(/\Aactions\/(checkout|upload-artifact)@[0-9a-f]{40}\z/)
}
upload = actions.find { |step| step['uses'].start_with?('actions/upload-artifact@') }
abort 'Results must survive failures' unless upload['if'] == 'always()'
abort 'Unbounded retention' unless upload['with']['retention-days'] == 7
checkout = actions.find { |step| step['uses'].start_with?('actions/checkout@') }
abort 'Credentials must not persist' unless checkout['with']['persist-credentials'] == false
RUBY

printf '%s\n' '9 headless CI helper/configuration checks passed. No real Apple tools were used.'
