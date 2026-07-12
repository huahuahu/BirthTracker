#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/codex-worktree-setup.sh"
TMP=""

cleanup_fixture() {
  if [[ -n "$TMP" && -d "$TMP" ]]; then
    rm -rf "$TMP"
  fi
  TMP=""
}

fail() {
  echo "FAIL: $*" >&2
  cleanup_fixture
  exit 1
}

run_and_capture() {
  set +e
  OUTPUT="$("$@" 2>&1)"
  STATUS=$?
  set -e
}

new_fixture() {
  TMP="$(mktemp -d)"
  SOURCE_TREE="$TMP/source tree"
  WORKTREE="$TMP/work tree"
  BIN="$TMP/bin"
  CALLS="$TMP/tool-calls.log"
  HOME_DIR="$TMP/home"

  mkdir -p "$SOURCE_TREE/Config" "$WORKTREE/.xcodebuildmcp" "$BIN" "$HOME_DIR"
  mkdir -p "$WORKTREE/AIOutput/DerivedData"
  SOURCE_TREE="$(cd "$SOURCE_TREE" && pwd -P)"
  WORKTREE="$(cd "$WORKTREE" && pwd -P)"
  printf '%s\n' stale > "$WORKTREE/AIOutput/DerivedData/stale.txt"
  printf '%s\n' 'APP_BUNDLE_ID = example.local' > "$SOURCE_TREE/Config/Project.xcconfig.example"
  cat > "$WORKTREE/.xcodebuildmcp/config.yaml" <<'YAML'
sessionDefaults:
  simulatorId: F4B82181-8A72-4AC3-9C95-454DE83A0C62
YAML
  : > "$CALLS"

  cat > "$BIN/xcodegen" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[[ "$#" -eq 1 && "$1" == "generate" ]] || {
  echo "unexpected xcodegen arguments: $*" >&2
  exit 1
}
printf 'xcodegen|%s|%s\n' "$(pwd -P)" "$*" >> "${CODEX_TEST_CALLS:?}"
mkdir -p BirthTracker.xcodeproj
STUB
  chmod +x "$BIN/xcodegen"

  cat > "$BIN/xcode-build-server" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
config)
  [[ "$#" -eq 7 ]] || {
    echo "unexpected config argument count: $#" >&2
    exit 1
  }
  [[ "$2" == "-workspace" && "$3" == "BirthTracker.xcodeproj/project.xcworkspace" ]] || {
    echo "unexpected config workspace arguments: $*" >&2
    exit 1
  }
  [[ "$4" == "-scheme" && "$5" == "BirthTracker" ]] || {
    echo "unexpected config scheme arguments: $*" >&2
    exit 1
  }
  [[ "$6" == "--build_root" && "$7" == "${CODEX_TEST_WORKTREE:?}/AIOutput/DerivedData" ]] || {
    echo "unexpected config build root arguments: $*" >&2
    exit 1
  }
  printf 'xcode-build-server|%s|%s\n' "$(pwd -P)" "$*" >> "${CODEX_TEST_CALLS:?}"
  cat > buildServer.json <<JSON
{
  "name": "stub build server",
  "workspace": "BirthTracker.xcodeproj/project.xcworkspace",
  "build_root": "${CODEX_TEST_WORKTREE:?}/AIOutput/DerivedData",
  "scheme": "BirthTrackerFromBuildServer",
  "kind": "xcode"
}
JSON
  ;;
parse)
  [[ "$#" -eq 7 ]] || {
    echo "unexpected parse argument count: $#" >&2
    exit 1
  }
  build_root="${CODEX_TEST_WORKTREE:?}/AIOutput/DerivedData"
  cache_root_key="${CODEX_TEST_WORKTREE//\//-}"
  build_root_hash="$(printf '%s' "$build_root" | md5 -q)"
  expected_compile_file="$HOME/Library/Caches/xcode-build-server/$cache_root_key/compile_file-BirthTrackerFromBuildServer-$build_root_hash"
  [[ "$2" == "-s" && "$3" == "$build_root" ]] || {
    echo "unexpected parse sync arguments: $*" >&2
    exit 1
  }
  [[ "$4" == "-o" && "$5" == "$expected_compile_file" ]] || {
    echo "unexpected parse output arguments: $*" >&2
    exit 1
  }
  [[ "$6" == "--scheme" && "$7" == "BirthTrackerFromBuildServer" ]] || {
    echo "unexpected parse scheme arguments: $*" >&2
    exit 1
  }
  printf 'xcode-build-server|%s|%s\n' "$(pwd -P)" "$*" >> "${CODEX_TEST_CALLS:?}"
  compile_parent=${5%/*}
  mkdir -p "$compile_parent"
  printf '%s\n' '{"module_name":"Features"}' > "$5"
  ;;
*)
  echo "unexpected xcode-build-server subcommand: $1" >&2
  exit 1
  ;;
esac
STUB
  chmod +x "$BIN/xcode-build-server"

  cat > "$BIN/xcodebuild" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
expected_args=(
  GCC_GENERATE_DEBUGGING_SYMBOLS=YES
  ONLY_ACTIVE_ARCH=YES
  COMPILER_INDEX_STORE_ENABLE=YES
  -workspace BirthTracker.xcodeproj/project.xcworkspace
  -scheme BirthTrackerFromBuildServer
  -configuration Debug
  -destination "platform=iOS Simulator,id=F4B82181-8A72-4AC3-9C95-454DE83A0C62"
  -resultBundlePath "${CODEX_TEST_WORKTREE:?}/AIOutput/BuildServer.xcresult"
  -allowProvisioningUpdates
  -derivedDataPath "$CODEX_TEST_WORKTREE/AIOutput/DerivedData"
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
[[ ! -e "${CODEX_TEST_WORKTREE:?}/AIOutput/DerivedData/stale.txt" ]] || {
  echo "xcodebuild should run after stale DerivedData is removed" >&2
  exit 1
}
printf 'xcodebuild|%s|%s\n' "$(pwd -P)" "$*" >> "${CODEX_TEST_CALLS:?}"
STUB
  chmod +x "$BIN/xcodebuild"
}

run_setup_with_path() {
  local setup_path="$1"
  shift
  run_and_capture env \
    PATH="$setup_path" \
    HOME="$HOME_DIR" \
    CODEX_TEST_CALLS="$CALLS" \
    CODEX_TEST_WORKTREE="$WORKTREE" \
    CODEX_SOURCE_TREE_PATH="$SOURCE_TREE" \
    CODEX_WORKTREE_PATH="$WORKTREE" \
    COPILOT_SCRIPT_TRIGGER=not-session-create \
    COPILOT_ROOT_PATH="$TMP/poison Copilot root" \
    COPILOT_WORKSPACE_PATH="$TMP/poison Copilot workspace" \
    /bin/bash "$SCRIPT" "$@"
}

run_setup() {
  run_setup_with_path "$BIN:$PATH"
}

test_requires_codex_paths() {
  run_and_capture env -u CODEX_WORKTREE_PATH -u CODEX_SOURCE_TREE_PATH bash "$SCRIPT"
  [[ "$STATUS" -eq 2 ]] || fail "missing worktree path should exit 2: $OUTPUT"
  [[ "$OUTPUT" == "error: CODEX_WORKTREE_PATH is required." ]] \
    || fail "unexpected missing worktree path output: $OUTPUT"

  TMP="$(mktemp -d)"
  run_and_capture env -u CODEX_SOURCE_TREE_PATH CODEX_WORKTREE_PATH="$TMP" bash "$SCRIPT"
  [[ "$STATUS" -eq 2 ]] || fail "missing source tree path should exit 2: $OUTPUT"
  [[ "$OUTPUT" == "error: CODEX_SOURCE_TREE_PATH is required." ]] \
    || fail "unexpected missing source tree path output: $OUTPUT"
  cleanup_fixture
}

test_rejects_invalid_codex_paths() {
  TMP="$(mktemp -d)"
  run_and_capture env \
    CODEX_SOURCE_TREE_PATH="$TMP" \
    CODEX_WORKTREE_PATH="$TMP/missing worktree" \
    bash "$SCRIPT"
  [[ "$STATUS" -eq 2 ]] || fail "invalid worktree path should exit 2: $OUTPUT"
  [[ "$OUTPUT" == "error: CODEX_WORKTREE_PATH does not exist: $TMP/missing worktree" ]] \
    || fail "unexpected invalid worktree path output: $OUTPUT"

  mkdir -p "$TMP/worktree"
  run_and_capture env \
    CODEX_SOURCE_TREE_PATH="$TMP/missing source tree" \
    CODEX_WORKTREE_PATH="$TMP/worktree" \
    bash "$SCRIPT"
  [[ "$STATUS" -eq 2 ]] || fail "invalid source tree path should exit 2: $OUTPUT"
  [[ "$OUTPUT" == "error: CODEX_SOURCE_TREE_PATH does not exist: $TMP/missing source tree" ]] \
    || fail "unexpected invalid source tree path output: $OUTPUT"
  cleanup_fixture
}

test_wrapper_does_not_require_dirname() {
  local checkout bin log tool tool_path
  TMP="$(mktemp -d)"
  checkout="$TMP/main checkout"
  bin="$TMP/bin"
  log="$checkout/AIOutput/codex-worktree-setup.log"
  mkdir -p "$checkout" "$bin"

  for tool in date mkdir; do
    tool_path="$(command -v "$tool")" || fail "test requires $tool"
    ln -s "$tool_path" "$bin/$tool"
  done

  run_and_capture env \
    PATH="$bin" \
    CODEX_SOURCE_TREE_PATH="$checkout" \
    CODEX_WORKTREE_PATH="$checkout" \
    /bin/sh "$SCRIPT"

  [[ "$STATUS" -eq 0 ]] || fail "Codex wrapper should not require dirname, got $STATUS: $OUTPUT"
  [[ -z "$OUTPUT" ]] || fail "Codex main-checkout output should be redirected to its log: $OUTPUT"
  grep -q "codex-worktree-setup: main checkout detected" "$log" \
    || fail "Codex wrapper should reach the shared setup without dirname"
  cleanup_fixture
}

test_stubs_reject_split_arguments() {
  local build_root_hash cache_root_key compile_file
  new_fixture

  run_and_capture env \
    CODEX_TEST_CALLS="$CALLS" \
    CODEX_TEST_WORKTREE="$WORKTREE" \
    /bin/bash -c '
      cd "$1"
      "$2" config \
        -workspace BirthTracker.xcodeproj/project.xcworkspace \
        -scheme BirthTracker \
        --build_root $1/AIOutput/DerivedData
    ' _ "$WORKTREE" "$BIN/xcode-build-server"
  [[ "$STATUS" -ne 0 ]] \
    || fail "xcode-build-server config stub accepted a split build root path"

  cache_root_key="$(printf '%s' "$WORKTREE" | sed 's#/#-#g')"
  build_root_hash="$(printf '%s' "$WORKTREE/AIOutput/DerivedData" | md5 -q)"
  compile_file="$HOME_DIR/Library/Caches/xcode-build-server/$cache_root_key/compile_file-BirthTrackerFromBuildServer-$build_root_hash"
  run_and_capture env \
    HOME="$HOME_DIR" \
    CODEX_TEST_CALLS="$CALLS" \
    CODEX_TEST_WORKTREE="$WORKTREE" \
    /bin/bash -c '
      cd "$1"
      "$2" parse \
        -s "$1/AIOutput/DerivedData" \
        -o $3 \
        --scheme BirthTrackerFromBuildServer
    ' _ "$WORKTREE" "$BIN/xcode-build-server" "$compile_file"
  [[ "$STATUS" -ne 0 ]] \
    || fail "xcode-build-server parse stub accepted a split compile file path"

  rm "$WORKTREE/AIOutput/DerivedData/stale.txt"
  run_and_capture env \
    CODEX_TEST_CALLS="$CALLS" \
    CODEX_TEST_WORKTREE="$WORKTREE" \
    /bin/bash -c '
      cd "$1"
      "$2" \
        GCC_GENERATE_DEBUGGING_SYMBOLS=YES \
        ONLY_ACTIVE_ARCH=YES \
        COMPILER_INDEX_STORE_ENABLE=YES \
        -workspace BirthTracker.xcodeproj/project.xcworkspace \
        -scheme BirthTrackerFromBuildServer \
        -configuration Debug \
        -destination "platform=iOS Simulator,id=F4B82181-8A72-4AC3-9C95-454DE83A0C62" \
        -resultBundlePath $1/AIOutput/BuildServer.xcresult \
        -allowProvisioningUpdates \
        -derivedDataPath "$1/AIOutput/DerivedData" \
        CODE_SIGNING_ALLOWED=NO \
        build-for-testing
    ' _ "$WORKTREE" "$BIN/xcodebuild"
  [[ "$STATUS" -ne 0 ]] || fail "xcodebuild stub accepted a split result bundle path"

  run_and_capture env \
    CODEX_TEST_CALLS="$CALLS" \
    CODEX_TEST_WORKTREE="$WORKTREE" \
    /bin/bash -c 'cd "$1" && "$2" generate unexpected' \
    _ "$WORKTREE" "$BIN/xcodegen"
  [[ "$STATUS" -ne 0 ]] || fail "xcodegen stub accepted unexpected arguments"
  cleanup_fixture
}

test_runs_full_initialization() {
  local cache_root_key build_root_hash compile_file expected_calls log
  new_fixture
  run_setup

  [[ "$STATUS" -eq 0 ]] || fail "Codex setup should exit 0: $OUTPUT"
  [[ -z "$OUTPUT" ]] || fail "Codex setup output should be redirected to log: $OUTPUT"
  [[ -f "$WORKTREE/Config/Project.xcconfig" ]] || fail "Codex setup should copy Project.xcconfig"
  cmp -s "$SOURCE_TREE/Config/Project.xcconfig.example" "$WORKTREE/Config/Project.xcconfig" \
    || fail "copied Project.xcconfig should match the source example"
  [[ ! -e "$WORKTREE/AIOutput/DerivedData/stale.txt" ]] \
    || fail "Codex setup should remove stale DerivedData"
  [[ -f "$WORKTREE/buildServer.json" ]] || fail "Codex setup should generate buildServer.json"

  cache_root_key="$(printf '%s' "$WORKTREE" | sed 's#/#-#g')"
  build_root_hash="$(printf '%s' "$WORKTREE/AIOutput/DerivedData" | md5 -q)"
  compile_file="$HOME_DIR/Library/Caches/xcode-build-server/$cache_root_key/compile_file-BirthTrackerFromBuildServer-$build_root_hash"
  [[ -s "$compile_file" ]] || fail "Codex setup should generate a non-empty compile cache"

  expected_calls="$TMP/expected-tool-calls.log"
  cat > "$expected_calls" <<EOF
xcodegen|$WORKTREE|generate
xcode-build-server|$WORKTREE|config -workspace BirthTracker.xcodeproj/project.xcworkspace -scheme BirthTracker --build_root $WORKTREE/AIOutput/DerivedData
xcodebuild|$WORKTREE|GCC_GENERATE_DEBUGGING_SYMBOLS=YES ONLY_ACTIVE_ARCH=YES COMPILER_INDEX_STORE_ENABLE=YES -workspace BirthTracker.xcodeproj/project.xcworkspace -scheme BirthTrackerFromBuildServer -configuration Debug -destination platform=iOS Simulator,id=F4B82181-8A72-4AC3-9C95-454DE83A0C62 -resultBundlePath $WORKTREE/AIOutput/BuildServer.xcresult -allowProvisioningUpdates -derivedDataPath $WORKTREE/AIOutput/DerivedData CODE_SIGNING_ALLOWED=NO build-for-testing
xcode-build-server|$WORKTREE|parse -s $WORKTREE/AIOutput/DerivedData -o $compile_file --scheme BirthTrackerFromBuildServer
EOF
  diff -u "$expected_calls" "$CALLS" || fail "Codex setup tool calls should match the full initialization flow"

  log="$WORKTREE/AIOutput/codex-worktree-setup.log"
  [[ -f "$log" ]] || fail "Codex setup log should exist"
  grep -q "codex-worktree-setup: copied Config/Project.xcconfig.example" "$log" \
    || fail "Codex log should record the config copy"
  grep -q "codex-worktree-setup: running xcodegen generate." "$log" \
    || fail "Codex log should record XcodeGen"
  grep -q "codex-worktree-setup: generating xcode-build-server config." "$log" \
    || fail "Codex log should record build server generation"
  grep -q "codex-worktree-setup: building BirthTracker for iOS Simulator." "$log" \
    || fail "Codex log should record the Simulator build"
  grep -q "codex-worktree-setup: generated xcode-build-server compile cache." "$log" \
    || fail "Codex log should record compile cache completion"
  cleanup_fixture
}

test_reports_missing_tool() {
  local log
  new_fixture
  rm "$BIN/xcodegen"

  run_setup_with_path "$BIN:/usr/bin:/bin:/usr/sbin:/sbin"

  [[ "$STATUS" -eq 127 ]] || fail "missing xcodegen should exit 127: $OUTPUT"
  log="$WORKTREE/AIOutput/codex-worktree-setup.log"
  grep -q "error: xcodegen is required to generate BirthTracker.xcodeproj." "$log" \
    || fail "Codex log should identify the missing xcodegen tool"
  cleanup_fixture
}

test_skips_main_checkout() {
  local checkout log
  TMP="$(mktemp -d)"
  checkout="$TMP/main checkout"
  mkdir -p "$checkout"

  run_and_capture env \
    CODEX_SOURCE_TREE_PATH="$checkout" \
    CODEX_WORKTREE_PATH="$checkout" \
    bash "$SCRIPT"

  [[ "$STATUS" -eq 0 ]] || fail "main checkout should exit 0: $OUTPUT"
  [[ ! -e "$checkout/Config/Project.xcconfig" ]] || fail "main checkout should not receive copied config"
  [[ ! -e "$checkout/BirthTracker.xcodeproj" ]] || fail "main checkout should not generate an Xcode project"
  log="$checkout/AIOutput/codex-worktree-setup.log"
  [[ -f "$log" ]] || fail "main checkout skip should still be logged"
  grep -q "codex-worktree-setup: main checkout detected; no config copy needed." "$log" \
    || fail "main checkout log should explain the skip"
  cleanup_fixture
}

test_preserves_existing_target_config() {
  new_fixture
  mkdir -p "$WORKTREE/Config"
  printf '%s\n' 'APP_BUNDLE_ID = existing.local' > "$WORKTREE/Config/Project.xcconfig"

  run_setup

  [[ "$STATUS" -eq 0 ]] || fail "Codex setup with existing config should exit 0: $OUTPUT"
  grep -q '^APP_BUNDLE_ID = existing.local$' "$WORKTREE/Config/Project.xcconfig" \
    || fail "Codex setup should preserve existing Project.xcconfig"
  grep -q "codex-worktree-setup: Config/Project.xcconfig already exists; leaving it unchanged." \
    "$WORKTREE/AIOutput/codex-worktree-setup.log" \
    || fail "Codex setup should log that existing config was preserved"
  cleanup_fixture
}

run_named_test() {
  case "$1" in
  requires-paths) test_requires_codex_paths ;;
  rejects-invalid-paths) test_rejects_invalid_codex_paths ;;
  wrapper-without-dirname) test_wrapper_does_not_require_dirname ;;
  stub-argument-guards) test_stubs_reject_split_arguments ;;
  full-initialization) test_runs_full_initialization ;;
  missing-tool) test_reports_missing_tool ;;
  main-checkout) test_skips_main_checkout ;;
  preserves-config) test_preserves_existing_target_config ;;
  *) fail "unknown test name: $1" ;;
  esac
}

if [[ "$#" -eq 1 ]]; then
  run_named_test "$1"
  echo "codex-worktree-setup test passed: $1"
  exit 0
fi

[[ "$#" -eq 0 ]] || fail "usage: test-codex-worktree-setup.sh [test-name]"

test_requires_codex_paths
test_rejects_invalid_codex_paths
test_wrapper_does_not_require_dirname
test_stubs_reject_split_arguments
test_runs_full_initialization
test_reports_missing_tool
test_skips_main_checkout
test_preserves_existing_target_config

echo "codex-worktree-setup tests passed"
