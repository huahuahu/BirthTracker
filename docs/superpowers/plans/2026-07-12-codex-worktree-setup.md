# Codex worktree 自动初始化实施计划

> **面向执行代理：** 必须使用 `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans`，按任务逐项执行本计划。各步骤使用 checkbox（`- [ ]`）跟踪。

**目标：** 为 Codex Environment 新增独立 worktree setup 入口，并让它与 Copilot session 共享完整的 XcodeGen、build server、Simulator 构建和 compile cache 初始化逻辑。

**架构：** 把 `scripts/copilot-session-create.sh` 中与平台无关的逻辑抽到 POSIX `sh` 脚本 `scripts/worktree-setup.sh`。Copilot 与 Codex 各自保留轻量入口，分别校验并规范化自己的环境变量，再以明确的日志文件名和消息前缀调用共享核心。

**技术栈：** POSIX `sh`、Bash 测试脚本、XcodeGen、xcode-build-server、xcodebuild、plutil、Make。

## 全局约束

- 所有规格和实施说明使用中文；README 保持仓库现有英文风格。
- 三个 lifecycle 脚本必须保持 POSIX `sh` 兼容。
- Codex 入口直接消费 `CODEX_SOURCE_TREE_PATH` 和 `CODEX_WORKTREE_PATH`，不得伪造 `COPILOT_*` 变量。
- 保留 Copilot 的 `session.create` trigger、日志路径、消息前缀及现有测试契约。
- Codex 日志固定为 `AIOutput/codex-worktree-setup.log`，消息前缀固定为 `codex-worktree-setup`。
- 不覆盖 worktree 已有的 `Config/Project.xcconfig`，不提交该本地配置和任何生成产物。
- 只允许清理当前 worktree 的 `AIOutput/DerivedData`，不得放宽现有 build root 安全检查。
- 缺少路径变量或路径无效时返回 `2`；缺少必要命令时返回 `127`；外部命令失败必须向上传播。
- 网络 fetch、install 或 upload 命令必须使用仓库 `AGENTS.md` 指定的 1082 完整代理环境；本计划不需要网络命令。
- SwiftPM 若遇到 bare repository 安全错误，只能对单次命令增加仓库规定的 `GIT_CONFIG_COUNT` override，不得修改全局 Git 配置。
- 完成代码变更后必须运行 `make check`。

---

### Task 1：抽取共享 worktree 初始化核心

**文件：**

- Create: `scripts/worktree-setup.sh`
- Modify: `scripts/copilot-session-create.sh`
- Test: `scripts/test-copilot-session-create.sh`

**接口：**

- Consumes: `scripts/worktree-setup.sh <source-tree> <worktree> <log-filename> <log-prefix>` 四个位置参数；前两个是入口脚本通过 `pwd -P` 规范化的绝对路径。
- Produces: 平台无关的完整初始化入口；Copilot wrapper 继续暴露现有 `COPILOT_SCRIPT_TRIGGER`、`COPILOT_ROOT_PATH` 和 `COPILOT_WORKSPACE_PATH` 接口。

- [ ] **Step 1：运行现有 Copilot characterization test 建立重构基线**

```bash
./scripts/test-copilot-session-create.sh
```

Expected: PASS，并输出 `copilot-session-create tests passed`。

- [ ] **Step 2：创建共享核心脚本**

Create `scripts/worktree-setup.sh` with this complete content:

```sh
#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
  echo "usage: worktree-setup.sh <source-tree> <worktree> <log-filename> <log-prefix>" >&2
  exit 2
fi

ROOT_PATH="$1"
WORKSPACE_PATH="$2"
LOG_FILENAME="$3"
LOG_PREFIX="$4"

mkdir -p "$WORKSPACE_PATH/AIOutput"
exec >> "$WORKSPACE_PATH/AIOutput/$LOG_FILENAME" 2>&1
date

if [ "$WORKSPACE_PATH" = "$ROOT_PATH" ]; then
  echo "$LOG_PREFIX: main checkout detected; no config copy needed."
  exit 0
fi

run_xcodegen() {
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen is required to generate BirthTracker.xcodeproj." >&2
    exit 127
  fi

  echo "$LOG_PREFIX: running xcodegen generate."
  (cd "$WORKSPACE_PATH" && xcodegen generate)
}

run_xcode_build_server() {
  if ! command -v xcode-build-server >/dev/null 2>&1; then
    echo "error: xcode-build-server is required to generate buildServer.json for VS Code." >&2
    exit 127
  fi

  echo "$LOG_PREFIX: generating xcode-build-server config."
  (
    cd "$WORKSPACE_PATH" &&
      xcode-build-server config \
        -workspace BirthTracker.xcodeproj/project.xcworkspace \
        -scheme BirthTracker \
        --build_root "$WORKSPACE_PATH/AIOutput/DerivedData"
  )

  if [ ! -f "$WORKSPACE_PATH/buildServer.json" ]; then
    echo "error: xcode-build-server did not generate buildServer.json." >&2
    exit 1
  fi

  echo "$LOG_PREFIX: generated buildServer.json."
}

read_build_server_value() {
  plutil -extract "$1" raw -o - "$WORKSPACE_PATH/buildServer.json"
}

read_xcodebuildmcp_session_default() {
  if [ ! -f "$WORKSPACE_PATH/.xcodebuildmcp/config.yaml" ]; then
    return 0
  fi

  awk -v key="$1:" '$1 == key { print $2; exit }' "$WORKSPACE_PATH/.xcodebuildmcp/config.yaml"
}

hash_text() {
  if command -v md5 >/dev/null 2>&1; then
    printf '%s' "$1" | md5 -q
  elif command -v md5sum >/dev/null 2>&1; then
    printf '%s' "$1" | md5sum | awk '{ print $1 }'
  else
    echo "error: md5 or md5sum is required to compute xcode-build-server cache paths." >&2
    exit 127
  fi
}

build_server_compile_file_path() {
  CACHE_ROOT_KEY="$(printf '%s' "$WORKSPACE_PATH" | sed 's#/#-#g')"
  BUILD_ROOT_HASH="$(hash_text "$BUILD_ROOT")"
  echo "$HOME/Library/Caches/xcode-build-server/$CACHE_ROOT_KEY/compile_file-$BUILD_SCHEME-$BUILD_ROOT_HASH"
}

run_xcodebuild() {
  if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "error: xcodebuild is required to build BirthTracker." >&2
    exit 127
  fi

  if ! command -v plutil >/dev/null 2>&1; then
    echo "error: plutil is required to read buildServer.json." >&2
    exit 127
  fi

  if ! BUILD_WORKSPACE="$(read_build_server_value workspace)"; then
    echo "error: buildServer.json is missing a workspace value." >&2
    exit 1
  fi

  if ! BUILD_SCHEME="$(read_build_server_value scheme)"; then
    echo "error: buildServer.json is missing a scheme value." >&2
    exit 1
  fi

  if ! BUILD_ROOT="$(read_build_server_value build_root)"; then
    echo "error: buildServer.json is missing a build_root value." >&2
    exit 1
  fi

  if [ -z "$BUILD_WORKSPACE" ] || [ -z "$BUILD_SCHEME" ] || [ -z "$BUILD_ROOT" ]; then
    echo "error: buildServer.json has empty workspace, scheme, or build_root values." >&2
    exit 1
  fi

  if [ "$BUILD_ROOT" != "$WORKSPACE_PATH/AIOutput/DerivedData" ]; then
    echo "error: refusing to clean unexpected build root: $BUILD_ROOT" >&2
    exit 1
  fi

  echo "$LOG_PREFIX: cleaning stale DerivedData."
  rm -rf "$BUILD_ROOT"

  BUILD_DESTINATION="generic/platform=iOS Simulator"
  if SIMULATOR_ID="$(read_xcodebuildmcp_session_default simulatorId)" && [ -n "$SIMULATOR_ID" ]; then
    BUILD_DESTINATION="platform=iOS Simulator,id=$SIMULATOR_ID"
  fi

  RESULT_BUNDLE_PATH="$WORKSPACE_PATH/AIOutput/BuildServer.xcresult"
  rm -rf "$RESULT_BUNDLE_PATH"

  COMPILE_FILE="$(build_server_compile_file_path)"
  mkdir -p "$(dirname "$COMPILE_FILE")"
  rm -f "$COMPILE_FILE" "$COMPILE_FILE.lock"

  echo "$LOG_PREFIX: building BirthTracker for iOS Simulator."
  (
    cd "$WORKSPACE_PATH" &&
      xcodebuild \
        GCC_GENERATE_DEBUGGING_SYMBOLS=YES \
        ONLY_ACTIVE_ARCH=YES \
        COMPILER_INDEX_STORE_ENABLE=YES \
        -workspace "$BUILD_WORKSPACE" \
        -scheme "$BUILD_SCHEME" \
        -configuration Debug \
        -destination "$BUILD_DESTINATION" \
        -resultBundlePath "$RESULT_BUNDLE_PATH" \
        -allowProvisioningUpdates \
        -derivedDataPath "$BUILD_ROOT" \
        CODE_SIGNING_ALLOWED=NO \
        build-for-testing
  )
  echo "$LOG_PREFIX: built BirthTracker for iOS Simulator."

  echo "$LOG_PREFIX: generating xcode-build-server compile cache."
  (cd "$WORKSPACE_PATH" && xcode-build-server parse -s "$BUILD_ROOT" -o "$COMPILE_FILE" --scheme "$BUILD_SCHEME")
  if [ ! -s "$COMPILE_FILE" ]; then
    echo "error: xcode-build-server did not generate compile cache." >&2
    exit 1
  fi
  echo "$LOG_PREFIX: generated xcode-build-server compile cache."
}

TARGET_DIR="$WORKSPACE_PATH/Config"
TARGET_CONFIG="$TARGET_DIR/Project.xcconfig"
MAIN_CONFIG="$ROOT_PATH/Config/Project.xcconfig"
EXAMPLE_CONFIG="$ROOT_PATH/Config/Project.xcconfig.example"

if [ -f "$TARGET_CONFIG" ]; then
  echo "$LOG_PREFIX: Config/Project.xcconfig already exists; leaving it unchanged."
elif [ -f "$MAIN_CONFIG" ]; then
  mkdir -p "$TARGET_DIR"
  cp -p "$MAIN_CONFIG" "$TARGET_CONFIG"
  echo "$LOG_PREFIX: copied local Config/Project.xcconfig into the workspace."
elif [ -f "$EXAMPLE_CONFIG" ]; then
  mkdir -p "$TARGET_DIR"
  cp -p "$EXAMPLE_CONFIG" "$TARGET_CONFIG"
  echo "$LOG_PREFIX: copied Config/Project.xcconfig.example into the workspace; update local signing values before building for device or release."
else
  echo "error: neither Config/Project.xcconfig nor Config/Project.xcconfig.example exists under source tree: $ROOT_PATH" >&2
  exit 1
fi

run_xcodegen
run_xcode_build_server
run_xcodebuild
```

- [ ] **Step 3：把 Copilot 脚本收敛为平台入口**

Replace `scripts/copilot-session-create.sh` with:

```sh
#!/bin/sh
set -eu

TRIGGER="${COPILOT_SCRIPT_TRIGGER:-}"

if [ "$TRIGGER" != "session.create" ]; then
  echo "copilot-session-create: skipping trigger '$TRIGGER'."
  exit 0
fi

if [ -z "${COPILOT_WORKSPACE_PATH:-}" ]; then
  echo "error: COPILOT_WORKSPACE_PATH is required." >&2
  exit 2
fi

if [ -z "${COPILOT_ROOT_PATH:-}" ]; then
  echo "error: COPILOT_ROOT_PATH is required." >&2
  exit 2
fi

if ! WORKSPACE_PATH="$(cd "$COPILOT_WORKSPACE_PATH" 2>/dev/null && pwd -P)"; then
  echo "error: COPILOT_WORKSPACE_PATH does not exist: $COPILOT_WORKSPACE_PATH" >&2
  exit 2
fi

if ! ROOT_PATH="$(cd "$COPILOT_ROOT_PATH" 2>/dev/null && pwd -P)"; then
  echo "error: COPILOT_ROOT_PATH does not exist: $COPILOT_ROOT_PATH" >&2
  exit 2
fi

SCRIPT_DIR="$(CDPATH= cd "$(dirname "$0")" && pwd -P)"

exec "$SCRIPT_DIR/worktree-setup.sh" \
  "$ROOT_PATH" \
  "$WORKSPACE_PATH" \
  "copilot-session-create.log" \
  "copilot-session-create"
```

```bash
chmod +x scripts/worktree-setup.sh scripts/copilot-session-create.sh
```

- [ ] **Step 4：运行 Copilot 回归测试**

```bash
./scripts/test-copilot-session-create.sh
```

Expected: PASS，并输出 `copilot-session-create tests passed`。任何失败都先修复共享核心，不放宽旧测试契约。

- [ ] **Step 5：提交共享核心重构**

```bash
git add scripts/worktree-setup.sh scripts/copilot-session-create.sh
git commit -m "refactor: share worktree setup logic"
```

---

### Task 2：用失败测试驱动 Codex Environment 入口

**文件：**

- Create: `scripts/codex-worktree-setup.sh`
- Create: `scripts/test-codex-worktree-setup.sh`
- Modify: `Makefile`
- Test: `scripts/test-codex-worktree-setup.sh`
- Test: `scripts/test-copilot-session-create.sh`

**接口：**

- Consumes: Codex Environment 提供的 `CODEX_SOURCE_TREE_PATH` 和 `CODEX_WORKTREE_PATH`。
- Produces: `scripts/codex-worktree-setup.sh`，它调用 Task 1 的四参数共享核心接口。

- [ ] **Step 1：创建 Codex 入口的失败测试**

Create `scripts/test-codex-worktree-setup.sh` with this complete content:

```bash
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
printf 'xcodegen|%s|%s\n' "$(pwd -P)" "$*" >> "${CODEX_TEST_CALLS:?}"
mkdir -p BirthTracker.xcodeproj
STUB
  chmod +x "$BIN/xcodegen"

  cat > "$BIN/xcode-build-server" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'xcode-build-server|%s|%s\n' "$(pwd -P)" "$*" >> "${CODEX_TEST_CALLS:?}"
case "$1" in
config)
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
  [[ "$4" == "-o" ]] || {
    echo "unexpected parse arguments: $*" >&2
    exit 1
  }
  mkdir -p "$(dirname "$5")"
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
[[ ! -e "${CODEX_TEST_WORKTREE:?}/AIOutput/DerivedData/stale.txt" ]] || {
  echo "xcodebuild should run after stale DerivedData is removed" >&2
  exit 1
}
printf 'xcodebuild|%s|%s\n' "$(pwd -P)" "$*" >> "${CODEX_TEST_CALLS:?}"
STUB
  chmod +x "$BIN/xcodebuild"
}

run_setup() {
  run_and_capture env \
    PATH="$BIN:$PATH" \
    HOME="$HOME_DIR" \
    CODEX_TEST_CALLS="$CALLS" \
    CODEX_TEST_WORKTREE="$WORKTREE" \
    CODEX_SOURCE_TREE_PATH="$SOURCE_TREE" \
    CODEX_WORKTREE_PATH="$WORKTREE" \
    COPILOT_SCRIPT_TRIGGER=not-session-create \
    COPILOT_ROOT_PATH="$TMP/poison Copilot root" \
    COPILOT_WORKSPACE_PATH="$TMP/poison Copilot workspace" \
    bash "$SCRIPT"
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

  run_setup

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

[[ -x "$SCRIPT" ]] || fail "scripts/codex-worktree-setup.sh should exist and be executable"

test_requires_codex_paths
test_rejects_invalid_codex_paths
test_runs_full_initialization
test_reports_missing_tool
test_skips_main_checkout
test_preserves_existing_target_config

echo "codex-worktree-setup tests passed"
```

```bash
chmod +x scripts/test-codex-worktree-setup.sh
```

Modify `Makefile` so both targets include the new test immediately after the Copilot test:

```make
check:
	./scripts/test-copilot-session-create.sh
	./scripts/test-codex-worktree-setup.sh
	./scripts/test-cleanup-merged-pr-worktree-on-archive.sh
	./scripts/test-widget-person-intent-storage.sh
	./scripts/lint.sh

test-scripts:
	./scripts/test-copilot-session-create.sh
	./scripts/test-codex-worktree-setup.sh
	./scripts/test-cleanup-merged-pr-worktree-on-archive.sh
	./scripts/test-widget-person-intent-storage.sh
```

- [ ] **Step 2：运行新测试并确认它因入口尚不存在而失败**

```bash
./scripts/test-codex-worktree-setup.sh
```

Expected: FAIL，包含 `FAIL: scripts/codex-worktree-setup.sh should exist and be executable`。

- [ ] **Step 3：实现最小 Codex 入口**

Create `scripts/codex-worktree-setup.sh` with:

```sh
#!/bin/sh
set -eu

if [ -z "${CODEX_WORKTREE_PATH:-}" ]; then
  echo "error: CODEX_WORKTREE_PATH is required." >&2
  exit 2
fi

if [ -z "${CODEX_SOURCE_TREE_PATH:-}" ]; then
  echo "error: CODEX_SOURCE_TREE_PATH is required." >&2
  exit 2
fi

if ! WORKSPACE_PATH="$(cd "$CODEX_WORKTREE_PATH" 2>/dev/null && pwd -P)"; then
  echo "error: CODEX_WORKTREE_PATH does not exist: $CODEX_WORKTREE_PATH" >&2
  exit 2
fi

if ! ROOT_PATH="$(cd "$CODEX_SOURCE_TREE_PATH" 2>/dev/null && pwd -P)"; then
  echo "error: CODEX_SOURCE_TREE_PATH does not exist: $CODEX_SOURCE_TREE_PATH" >&2
  exit 2
fi

SCRIPT_DIR="$(CDPATH= cd "$(dirname "$0")" && pwd -P)"

exec "$SCRIPT_DIR/worktree-setup.sh" \
  "$ROOT_PATH" \
  "$WORKSPACE_PATH" \
  "codex-worktree-setup.log" \
  "codex-worktree-setup"
```

```bash
chmod +x scripts/codex-worktree-setup.sh
```

- [ ] **Step 4：运行 Codex 测试并确认通过**

```bash
./scripts/test-codex-worktree-setup.sh
```

Expected: PASS，并输出 `codex-worktree-setup tests passed`。

- [ ] **Step 5：运行全部 lifecycle script 测试**

```bash
make test-scripts
```

Expected: exit `0`，且 Copilot、Codex、cleanup 和 widget storage 四个脚本均执行。

- [ ] **Step 6：提交 Codex 入口与测试**

```bash
git add Makefile scripts/codex-worktree-setup.sh scripts/test-codex-worktree-setup.sh
git commit -m "feat: add Codex worktree setup"
```

---

### Task 3：记录 Environment 配置并完成全量验证

**文件：**

- Modify: `README.md`
- Test: `Makefile`

**接口：**

- Consumes: Task 2 产出的 Codex setup 入口和两个 Codex 路径变量。
- Produces: 可直接粘贴的 Environment Setup script，以及日志和失败语义说明。

- [ ] **Step 1：验证 README 当前尚未记录 Codex Setup script**

```bash
rg -n 'CODEX_WORKTREE_PATH|codex-worktree-setup\.sh|codex-worktree-setup\.log' README.md
```

Expected: exit `1`，没有匹配输出。

- [ ] **Step 2：添加 Codex Environment 使用说明**

在现有 Copilot worktree session 段落后插入：

````markdown
For Codex Environment worktrees, use the following Setup script. Codex provides the source checkout and new worktree paths through `CODEX_SOURCE_TREE_PATH` and `CODEX_WORKTREE_PATH`:

```sh
cd "$CODEX_WORKTREE_PATH"
./scripts/codex-worktree-setup.sh
```

The Codex entry runs the same complete initialization flow as the Copilot lifecycle entry while keeping the platform-specific environment variables separate. It copies the local Xcode configuration when needed, runs XcodeGen, generates `buildServer.json`, performs the Simulator `build-for-testing`, and generates the xcode-build-server compile cache. Output is written to `AIOutput/codex-worktree-setup.log`. Missing tools, invalid paths, or incomplete generation fail the Setup script instead of leaving a partially initialized worktree.
````

- [ ] **Step 3：验证 README 包含完整配置与日志位置**

```bash
rg -n 'CODEX_SOURCE_TREE_PATH|CODEX_WORKTREE_PATH|scripts/codex-worktree-setup\.sh|AIOutput/codex-worktree-setup\.log' README.md
```

Expected: PASS，四个关键项都有匹配。

- [ ] **Step 4：运行仓库全量检查**

```bash
make check
```

Expected: exit `0`；Copilot 测试、Codex 测试、其他 lifecycle tests、SwiftFormat 检查和 SwiftLint 均通过。

- [ ] **Step 5：检查变更范围与生成文件**

```bash
git status --short
git --no-pager diff --check
git --no-pager diff -- README.md Makefile scripts/copilot-session-create.sh scripts/worktree-setup.sh scripts/codex-worktree-setup.sh scripts/test-codex-worktree-setup.sh
```

Expected:

- 只有本计划列出的源码、测试和文档文件发生变化。
- 不出现 `Config/Project.xcconfig`、`BirthTracker.xcodeproj`、`buildServer.json`、`AIOutput/DerivedData` 或 xcresult。
- `git diff --check` 无输出并返回 `0`。

- [ ] **Step 6：提交文档**

```bash
git add README.md
git commit -m "docs: document Codex worktree setup"
```

- [ ] **Step 7：提交后重新验证最终状态**

```bash
make check
git status --short
git log -3 --oneline
```

Expected:

- `make check` 再次返回 `0`。
- `git status --short` 无输出。
- 最近三条实现提交依次覆盖共享核心重构、Codex 入口与测试、README 文档。

实现完成后，当前 Codex worktree 若仍处于 detached HEAD，使用 Codex 应用的创建分支交接路径，不擅自 push 或修改远端状态。
