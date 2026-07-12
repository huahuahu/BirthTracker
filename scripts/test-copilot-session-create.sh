#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/copilot-session-create.sh"
CORE_SCRIPT="$ROOT/scripts/worktree-setup.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

run_and_capture() {
  set +e
  OUTPUT="$("$@" 2>&1)"
  STATUS=$?
  set -e
}

setup_error_propagation_fixture() {
  local main="$1"
  local workspace="$2"
  local bin="$3"

  mkdir -p "$main/Config" "$workspace/.xcodebuildmcp" "$bin"
  printf '%s\n' 'APP_BUNDLE_ID = example.local' > "$main/Config/Project.xcconfig.example"
  cat > "$workspace/.xcodebuildmcp/config.yaml" <<'YAML'
sessionDefaults:
  simulatorId: F4B82181-8A72-4AC3-9C95-454DE83A0C62
YAML

  cat > "$bin/xcodegen" <<'STUB'
#!/bin/sh
set -eu
mkdir -p BirthTracker.xcodeproj
STUB
  chmod +x "$bin/xcodegen"

  cat > "$bin/xcode-build-server" <<'STUB'
#!/bin/sh
set -eu
expected_workspace="${COPILOT_TEST_EXPECTED_WORKSPACE:?}"

case "$1" in
config)
  cat > buildServer.json <<JSON
{
  "workspace": "BirthTracker.xcodeproj/project.xcworkspace",
  "build_root": "$expected_workspace/AIOutput/DerivedData",
  "scheme": "BirthTrackerFromBuildServer"
}
JSON
  ;;
parse)
  mkdir -p "$(dirname "$5")"
  printf '%s\n' '{"module_name":"Features"}' > "$5"
  ;;
*)
  exit 1
  ;;
esac
STUB
  chmod +x "$bin/xcode-build-server"

  cat > "$bin/xcodebuild" <<'STUB'
#!/bin/sh
exit 0
STUB
  chmod +x "$bin/xcodebuild"
}

test_logs_session_create_output_to_aioutput() {
  local tmp main workspace bin log
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  main="$tmp/main"
  workspace="$tmp/workspace"
  bin="$tmp/bin"
  log="$workspace/AIOutput/copilot-session-create.log"

  mkdir -p "$main/Config" "$workspace/.xcodebuildmcp" "$bin"
  mkdir -p "$workspace/AIOutput/DerivedData"
  printf '%s\n' stale > "$workspace/AIOutput/DerivedData/stale.txt"
  printf '%s\n' 'APP_BUNDLE_ID = example.local' > "$main/Config/Project.xcconfig.example"
  cat > "$workspace/.xcodebuildmcp/config.yaml" <<'YAML'
sessionDefaults:
  simulatorId: F4B82181-8A72-4AC3-9C95-454DE83A0C62
YAML
  cat > "$bin/xcodegen" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p BirthTracker.xcodeproj
echo "stub xcodegen ran"
STUB
  chmod +x "$bin/xcodegen"

  cat > "$bin/xcode-build-server" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
expected_workspace="${COPILOT_TEST_EXPECTED_WORKSPACE:?}"
[[ "$(pwd -P)" == "$expected_workspace" ]] || {
  echo "unexpected xcode-build-server working directory: $(pwd -P)" >&2
  exit 1
}
case "$1" in
config)
[[ "$#" -eq 7 ]] || {
  echo "unexpected xcode-build-server config argument count: $#" >&2
  exit 1
}
;;
parse)
[[ "$#" -eq 7 ]] || {
  echo "unexpected xcode-build-server parse argument count: $#" >&2
  exit 1
}
;;
*)
  echo "unexpected xcode-build-server subcommand: $1" >&2
  exit 1
  ;;
esac

if [[ "$1" == "parse" ]]; then
  build_root="$expected_workspace/AIOutput/DerivedData"
  build_root_hash="$(printf '%s' "$build_root" | md5 -q)"
  expected_cache="$HOME/Library/Caches/xcode-build-server/${expected_workspace//\//-}/compile_file-BirthTrackerFromBuildServer-$build_root_hash"
  [[ "$2" == "-s" && "$3" == "$expected_workspace/AIOutput/DerivedData" ]] || {
    echo "unexpected xcode-build-server parse sync arguments: $*" >&2
    exit 1
  }
  [[ "$4" == "-o" && "$5" == "$expected_cache" ]] || {
    echo "unexpected xcode-build-server parse output arguments: $*" >&2
    exit 1
  }
  [[ "$6" == "--scheme" && "$7" == "BirthTrackerFromBuildServer" ]] || {
    echo "unexpected xcode-build-server parse scheme arguments: $*" >&2
    exit 1
  }
  mkdir -p "$(dirname "$5")"
  printf '{"module_name":"Features"}\n' > "$5"
  echo "stub xcode-build-server parse ran"
  exit 0
fi

[[ "$2" == "-workspace" && "$3" == "BirthTracker.xcodeproj/project.xcworkspace" ]] || {
  echo "unexpected xcode-build-server workspace arguments: $*" >&2
  exit 1
}
[[ "$4" == "-scheme" && "$5" == "BirthTracker" ]] || {
  echo "unexpected xcode-build-server scheme arguments: $*" >&2
  exit 1
}
[[ "$6" == "--build_root" && "$7" == "$expected_workspace/AIOutput/DerivedData" ]] || {
  echo "unexpected xcode-build-server build root arguments: $*" >&2
  exit 1
}
cat > buildServer.json <<JSON
{
  "name": "stub build server",
  "workspace": "BirthTracker.xcodeproj/project.xcworkspace",
  "build_root": "$expected_workspace/AIOutput/DerivedData",
  "scheme": "BirthTrackerFromBuildServer",
  "kind": "xcode"
}
JSON
echo "stub xcode-build-server ran"
STUB
  chmod +x "$bin/xcode-build-server"

  cat > "$bin/xcodebuild" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
expected_workspace="${COPILOT_TEST_EXPECTED_WORKSPACE:?}"
[[ "$(pwd -P)" == "$expected_workspace" ]] || {
  echo "unexpected xcodebuild working directory: $(pwd -P)" >&2
  exit 1
}
[[ ! -e "$expected_workspace/AIOutput/DerivedData/stale.txt" ]] || {
  echo "xcodebuild should run after stale DerivedData is removed" >&2
  exit 1
}
expected_args=(
  GCC_GENERATE_DEBUGGING_SYMBOLS=YES
  ONLY_ACTIVE_ARCH=YES
  COMPILER_INDEX_STORE_ENABLE=YES
  -workspace BirthTracker.xcodeproj/project.xcworkspace
  -scheme BirthTrackerFromBuildServer
  -configuration Debug
  -destination "platform=iOS Simulator,id=F4B82181-8A72-4AC3-9C95-454DE83A0C62"
  -resultBundlePath "$expected_workspace/AIOutput/BuildServer.xcresult"
  -allowProvisioningUpdates
  -derivedDataPath "$expected_workspace/AIOutput/DerivedData"
  CODE_SIGNING_ALLOWED=NO
  build-for-testing
)
args=("$@")
[[ "${#args[@]}" -eq "${#expected_args[@]}" ]] || {
  echo "unexpected xcodebuild argument count: $#" >&2
  exit 1
}
for index in "${!expected_args[@]}"; do
  [[ "${args[$index]}" == "${expected_args[$index]}" ]] || {
    echo "unexpected xcodebuild argument at $index: $*" >&2
    exit 1
  }
done
printf '%s\n' "$*" > "$expected_workspace/AIOutput/xcodebuild-args.txt"
echo "stub xcodebuild ran"
STUB
  chmod +x "$bin/xcodebuild"

  run_and_capture env \
    PATH="$bin:$PATH" \
    HOME="$workspace/home" \
    COPILOT_TEST_EXPECTED_WORKSPACE="$(cd "$workspace" && pwd -P)" \
    COPILOT_SCRIPT_TRIGGER=session.create \
    COPILOT_WORKSPACE_PATH="$workspace" \
    COPILOT_ROOT_PATH="$main" \
    bash "$SCRIPT"

  [[ "$STATUS" -eq 0 ]] || fail "session create should exit 0: $OUTPUT"
  [[ -z "$OUTPUT" ]] || fail "session create output should be redirected to log, got: $OUTPUT"
  [[ -f "$log" ]] || fail "session create log should exist"
  [[ -f "$workspace/buildServer.json" ]] || fail "session create should generate buildServer.json"
  grep -q "$(date +%Y)" "$log" || fail "session create log should include a date line"
  grep -q "copilot-session-create: copied Config/Project.xcconfig.example" "$log" \
    || fail "session create log should include config copy output"
  grep -q "copilot-session-create: running xcodegen generate." "$log" \
    || fail "session create log should include xcodegen start output"
  grep -q "stub xcodegen ran" "$log" || fail "session create log should include xcodegen output"
  grep -q "copilot-session-create: generating xcode-build-server config." "$log" \
    || fail "session create log should include xcode-build-server start output"
  grep -q "stub xcode-build-server ran" "$log" \
    || fail "session create log should include xcode-build-server output"
  grep -q "copilot-session-create: generated buildServer.json." "$log" \
    || fail "session create log should include buildServer.json completion output"
  [[ -f "$workspace/AIOutput/xcodebuild-args.txt" ]] \
    || fail "session create should build the project with xcodebuild"
  grep -q "copilot-session-create: cleaning stale DerivedData." "$log" \
    || fail "session create log should include DerivedData cleanup output"
  grep -q "copilot-session-create: building BirthTracker for iOS Simulator." "$log" \
    || fail "session create log should include xcodebuild start output"
  grep -q "stub xcodebuild ran" "$log" || fail "session create log should include xcodebuild output"
  grep -q "copilot-session-create: built BirthTracker for iOS Simulator." "$log" \
    || fail "session create log should include xcodebuild completion output"
  grep -q "stub xcode-build-server parse ran" "$log" \
    || fail "session create log should include xcode-build-server parse output"
  grep -q "copilot-session-create: generated xcode-build-server compile cache." "$log" \
    || fail "session create log should include compile cache completion output"
}

test_skips_when_trigger_is_unset() {
  local tmp main workspace bin log
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  main="$tmp/main"
  workspace="$tmp/workspace"
  bin="$tmp/bin"
  log="$workspace/AIOutput/copilot-session-create.log"

  mkdir -p "$main/Config" "$workspace" "$bin"
  printf '%s\n' 'APP_BUNDLE_ID = example.local' > "$main/Config/Project.xcconfig.example"
  cat > "$bin/xcodegen" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "xcodegen should not run when COPILOT_SCRIPT_TRIGGER is unset" >&2
exit 42
STUB
  chmod +x "$bin/xcodegen"

  cat > "$bin/xcode-build-server" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "xcode-build-server should not run when COPILOT_SCRIPT_TRIGGER is unset" >&2
exit 43
STUB
  chmod +x "$bin/xcode-build-server"

  run_and_capture env -u COPILOT_SCRIPT_TRIGGER \
    PATH="$bin:$PATH" \
    COPILOT_WORKSPACE_PATH="$workspace" \
    COPILOT_ROOT_PATH="$main" \
    bash "$SCRIPT"

  [[ "$STATUS" -eq 0 ]] || fail "unset trigger should exit 0: $OUTPUT"
  [[ "$OUTPUT" == "copilot-session-create: skipping trigger ''." ]] \
    || fail "unset trigger should print skip output, got: $OUTPUT"
  [[ ! -f "$log" ]] || fail "unset trigger should not create a session create log"
  [[ ! -f "$workspace/buildServer.json" ]] || fail "unset trigger should not generate buildServer.json"
}

test_propagates_simulator_id_read_failure() {
  local tmp main workspace bin
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  main="$tmp/main"
  workspace="$tmp/workspace"
  bin="$tmp/bin"
  setup_error_propagation_fixture "$main" "$workspace" "$bin"

  cat > "$bin/awk" <<'STUB'
#!/bin/sh
exit 73
STUB
  chmod +x "$bin/awk"

  run_and_capture env \
    PATH="$bin:$PATH" \
    HOME="$workspace/home" \
    COPILOT_TEST_EXPECTED_WORKSPACE="$(cd "$workspace" && pwd -P)" \
    COPILOT_SCRIPT_TRIGGER=session.create \
    COPILOT_WORKSPACE_PATH="$workspace" \
    COPILOT_ROOT_PATH="$main" \
    bash "$SCRIPT"

  [[ "$STATUS" -eq 73 ]] \
    || fail "simulator ID read failure should preserve status 73, got $STATUS"
}

test_returns_127_when_awk_is_missing() {
  local tmp main workspace bin tool tool_path log
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  main="$tmp/main"
  workspace="$tmp/workspace"
  bin="$tmp/bin"
  log="$workspace/AIOutput/copilot-session-create.log"
  setup_error_propagation_fixture "$main" "$workspace" "$bin"

  for tool in cat cp date dirname md5 mkdir plutil rm sed; do
    tool_path="$(command -v "$tool")" || fail "test requires $tool"
    ln -s "$tool_path" "$bin/$tool"
  done

  run_and_capture env \
    PATH="$bin" \
    HOME="$workspace/home" \
    COPILOT_TEST_EXPECTED_WORKSPACE="$(cd "$workspace" && pwd -P)" \
    COPILOT_SCRIPT_TRIGGER=session.create \
    COPILOT_WORKSPACE_PATH="$workspace" \
    COPILOT_ROOT_PATH="$main" \
    /bin/bash "$SCRIPT"

  [[ "$STATUS" -eq 127 ]] || fail "missing awk should exit 127, got $STATUS"
  grep -q "error: awk is required to read .xcodebuildmcp/config.yaml." "$log" \
    || fail "missing awk should write a clear error to the session log"
}

test_propagates_md5sum_failure() {
  local tmp main workspace bin
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  main="$tmp/main"
  workspace="$tmp/workspace"
  bin="$tmp/bin"
  setup_error_propagation_fixture "$main" "$workspace" "$bin"

  cat > "$bin/md5sum" <<'STUB'
#!/bin/sh
exit 74
STUB
  chmod +x "$bin/md5sum"

  run_and_capture env \
    PATH="$bin:/usr/bin:/bin" \
    HOME="$workspace/home" \
    COPILOT_TEST_EXPECTED_WORKSPACE="$(cd "$workspace" && pwd -P)" \
    COPILOT_SCRIPT_TRIGGER=session.create \
    COPILOT_WORKSPACE_PATH="$workspace" \
    COPILOT_ROOT_PATH="$main" \
    bash "$SCRIPT"

  [[ "$STATUS" -eq 74 ]] || fail "md5sum failure should preserve status 74, got $STATUS"
}

test_propagates_sed_failure() {
  local tmp main workspace bin
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  main="$tmp/main"
  workspace="$tmp/workspace"
  bin="$tmp/bin"
  setup_error_propagation_fixture "$main" "$workspace" "$bin"

  cat > "$bin/sed" <<'STUB'
#!/bin/sh
exit 75
STUB
  chmod +x "$bin/sed"

  run_and_capture env \
    PATH="$bin:$PATH" \
    HOME="$workspace/home" \
    COPILOT_TEST_EXPECTED_WORKSPACE="$(cd "$workspace" && pwd -P)" \
    /bin/bash "$CORE_SCRIPT" \
    "$(cd "$main" && pwd -P)" \
    "$(cd "$workspace" && pwd -P)" \
    "copilot-session-create.log" \
    "copilot-session-create"

  [[ "$STATUS" -eq 75 ]] || fail "sed failure should preserve status 75, got $STATUS"
}

test_returns_127_when_sed_is_missing() {
  local tmp main workspace bin tool tool_path log
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  main="$tmp/main"
  workspace="$tmp/workspace"
  bin="$tmp/bin"
  log="$workspace/AIOutput/copilot-session-create.log"
  setup_error_propagation_fixture "$main" "$workspace" "$bin"

  for tool in awk cat cp date dirname md5 mkdir plutil rm; do
    tool_path="$(command -v "$tool")" || fail "test requires $tool"
    ln -s "$tool_path" "$bin/$tool"
  done

  run_and_capture env \
    PATH="$bin" \
    HOME="$workspace/home" \
    COPILOT_TEST_EXPECTED_WORKSPACE="$(cd "$workspace" && pwd -P)" \
    /bin/bash "$CORE_SCRIPT" \
    "$(cd "$main" && pwd -P)" \
    "$(cd "$workspace" && pwd -P)" \
    "copilot-session-create.log" \
    "copilot-session-create"

  [[ "$STATUS" -eq 127 ]] || fail "missing sed should exit 127, got $STATUS"
  grep -q "error: sed is required to compute xcode-build-server cache paths." "$log" \
    || fail "missing sed should write a clear error to the session log"
}

[[ -x "$CORE_SCRIPT" ]] || fail "scripts/worktree-setup.sh should exist and be executable"

test_skips_when_trigger_is_unset
test_logs_session_create_output_to_aioutput
test_returns_127_when_sed_is_missing
test_propagates_sed_failure
test_returns_127_when_awk_is_missing
test_propagates_md5sum_failure
test_propagates_simulator_id_read_failure

echo "copilot-session-create tests passed"
