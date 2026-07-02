#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/copilot-session-create.sh"

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

test_logs_session_create_output_to_aioutput() {
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
[[ "$#" -eq 5 ]] || {
  echo "unexpected xcode-build-server argument count: $#" >&2
  exit 1
}
[[ "$1" == "config" ]] || {
  echo "unexpected xcode-build-server subcommand: $1" >&2
  exit 1
}
[[ "$2" == "-project" && "$3" == "BirthTracker.xcodeproj" ]] || {
  echo "unexpected xcode-build-server project arguments: $*" >&2
  exit 1
}
[[ "$4" == "-scheme" && "$5" == "BirthTracker" ]] || {
  echo "unexpected xcode-build-server scheme arguments: $*" >&2
  exit 1
}
printf '{"name":"stub build server"}\n' > buildServer.json
echo "stub xcode-build-server ran"
STUB
  chmod +x "$bin/xcode-build-server"

  run_and_capture env \
    PATH="$bin:$PATH" \
    COPILOT_TEST_EXPECTED_WORKSPACE="$workspace" \
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
}

test_logs_session_create_output_to_aioutput

echo "copilot-session-create tests passed"
