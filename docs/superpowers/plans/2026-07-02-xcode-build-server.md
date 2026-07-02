# Xcode Build Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Copilot worktree session 创建脚本中自动生成 `buildServer.json`，让 VS Code 的 SourceKit-LSP 可以点击 Swift 符号、属性和类型跳到定义。

**Architecture:** `scripts/copilot-session-create.sh` 继续负责 session 初始化：复制本地 xcconfig、运行 XcodeGen、再运行 xcode-build-server。测试通过 stub `xcodegen` 和 `xcode-build-server` 验证调用顺序、参数、日志和生成文件。README 同步说明新 session 生命周期脚本会同时生成 Xcode 工程和 build server 配置。

**Tech Stack:** POSIX shell, Bash script tests, XcodeGen, xcode-build-server, SourceKit-LSP, VS Code.

## Global Constraints

- `BirthTracker.xcodeproj` 是 XcodeGen 生成文件，不提交。
- `Config/Project.xcconfig` 是本地签名配置，不提交。
- `buildServer.json` 是 session 本地生成文件，不提交。
- `xcode-build-server` 必须在 `xcodegen generate` 之后运行。
- 缺少 `xcode-build-server`、配置命令失败或未生成 `buildServer.json` 时必须让脚本失败。
- lifecycle 脚本输出继续写入 `AIOutput/copilot-session-create.log`。
- 代码变更完成后运行 `make check`。

---

## File Structure

- Modify: `scripts/test-copilot-session-create.sh`
  - 负责 lifecycle 脚本的本地 shell 测试。
  - 增加 `xcode-build-server` stub，验证参数并创建 `buildServer.json`。
- Modify: `scripts/copilot-session-create.sh`
  - 负责 Copilot worktree session 初始化。
  - 新增 `run_xcode_build_server`，在 XcodeGen 后严格生成 build server 配置。
- Modify: `README.md`
  - 同步更新 Copilot worktree session 说明，明确脚本会生成 `buildServer.json` 以支持 VS Code 跳定义。
- Modify: `.gitignore`
  - 忽略 session 本地生成的 `buildServer.json`，防止路径相关配置被误提交。

---

### Task 1: Add failing lifecycle test for xcode-build-server

**Files:**
- Modify: `scripts/test-copilot-session-create.sh`

**Interfaces:**
- Consumes: `scripts/copilot-session-create.sh` 当前行为：复制 config、运行 `xcodegen generate`、日志写入 `AIOutput/copilot-session-create.log`。
- Produces: 一个会失败的测试，要求脚本调用 `xcode-build-server config -project BirthTracker.xcodeproj -scheme BirthTracker` 并生成 `$workspace/buildServer.json`。

- [ ] **Step 1: Replace the test with xcode-build-server expectations**

Edit `scripts/test-copilot-session-create.sh` so the full file content is:

```bash
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
}

test_logs_session_create_output_to_aioutput

echo "copilot-session-create tests passed"
```

- [ ] **Step 2: Run the focused script test and verify it fails**

Run:

```bash
./scripts/test-copilot-session-create.sh
```

Expected: FAIL with this message because `scripts/copilot-session-create.sh` does not yet call `xcode-build-server`:

```text
FAIL: session create should generate buildServer.json
```

- [ ] **Step 3: Commit the failing test**

```bash
git add scripts/test-copilot-session-create.sh
git commit -m "test: require xcode build server setup" -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 2: Generate buildServer.json during session creation

**Files:**
- Modify: `scripts/copilot-session-create.sh`

**Interfaces:**
- Consumes: Task 1 test expectation that `xcode-build-server` is called in the workspace with `config -project BirthTracker.xcodeproj -scheme BirthTracker`.
- Produces: `run_xcode_build_server()` shell function; lifecycle script creates `$WORKSPACE_PATH/buildServer.json` after `run_xcodegen`.

- [ ] **Step 1: Add the xcode-build-server function**

In `scripts/copilot-session-create.sh`, insert this function after `run_xcodegen()`:

```sh
run_xcode_build_server() {
  if ! command -v xcode-build-server >/dev/null 2>&1; then
    echo "error: xcode-build-server is required to generate buildServer.json for VS Code." >&2
    exit 127
  fi

  echo "copilot-session-create: generating xcode-build-server config."
  (cd "$WORKSPACE_PATH" && xcode-build-server config -project BirthTracker.xcodeproj -scheme BirthTracker)

  if [ ! -f "$WORKSPACE_PATH/buildServer.json" ]; then
    echo "error: xcode-build-server did not generate buildServer.json." >&2
    exit 1
  fi

  echo "copilot-session-create: generated buildServer.json."
}
```

- [ ] **Step 2: Call the function after XcodeGen**

At the bottom of `scripts/copilot-session-create.sh`, change:

```sh
run_xcodegen
```

to:

```sh
run_xcodegen
run_xcode_build_server
```

- [ ] **Step 3: Run the focused script test and verify it passes**

Run:

```bash
./scripts/test-copilot-session-create.sh
```

Expected:

```text
copilot-session-create tests passed
```

- [ ] **Step 4: Commit the implementation**

```bash
git add scripts/copilot-session-create.sh
git commit -m "feat: generate xcode build server config" -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```

---

### Task 3: Document the VS Code jump-to-definition setup and run full checks

**Files:**
- Modify: `README.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: Task 2 behavior that session creation now runs XcodeGen and xcode-build-server.
- Produces: README text explaining that the lifecycle script generates `buildServer.json` for VS Code SourceKit-LSP jump-to-definition support; `.gitignore` ignores root `buildServer.json`.

- [ ] **Step 1: Update README session lifecycle text**

In `README.md`, replace the paragraph that currently says:

```markdown
For Copilot worktree sessions, add `./scripts/copilot-session-create.sh` as a `session.create` lifecycle script. It copies the ignored local `Config/Project.xcconfig` from the main checkout into new worktrees when missing, falls back to `Config/Project.xcconfig.example`, and then runs `xcodegen generate` in the worktree.
```

with:

```markdown
For Copilot worktree sessions, add `./scripts/copilot-session-create.sh` as a `session.create` lifecycle script. It copies the ignored local `Config/Project.xcconfig` from the main checkout into new worktrees when missing, falls back to `Config/Project.xcconfig.example`, runs `xcodegen generate`, and then runs `xcode-build-server config -project BirthTracker.xcodeproj -scheme BirthTracker` in the worktree. The generated `buildServer.json` lets VS Code SourceKit-LSP resolve Swift build settings so clicking symbols, properties, and types can jump to their definitions.
```

- [ ] **Step 2: Ignore generated buildServer.json**

In `.gitignore`, add `buildServer.json` below the generated Xcode project entries:

```gitignore
buildServer.json
```

- [ ] **Step 3: Run the repository check**

Run:

```bash
make check
```

Expected output includes:

```text
copilot-session-create tests passed
```

Expected final status: command exits with status `0`.

- [ ] **Step 4: Verify buildServer.json is ignored**

Run:

```bash
git check-ignore -q buildServer.json
```

Expected final status: command exits with status `0`.

- [ ] **Step 5: Inspect final git diff**

Run:

```bash
git --no-pager diff -- scripts/copilot-session-create.sh scripts/test-copilot-session-create.sh README.md .gitignore
```

Expected:

- `scripts/copilot-session-create.sh` contains `run_xcode_build_server`.
- `scripts/copilot-session-create.sh` calls `run_xcode_build_server` immediately after `run_xcodegen`.
- `scripts/test-copilot-session-create.sh` includes the `xcode-build-server` stub and `buildServer.json` assertions.
- `README.md` mentions `buildServer.json` and VS Code SourceKit-LSP jump-to-definition support.
- `.gitignore` ignores `buildServer.json`.

- [ ] **Step 6: Commit documentation and verified changes**

```bash
git add README.md .gitignore docs/superpowers/plans/2026-07-02-xcode-build-server.md
git commit -m "docs: describe xcode build server setup" -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>"
```
