#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/cleanup-merged-pr-worktree-on-archive.sh"

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

assert_output_contains() {
  case "$OUTPUT" in
    *"$1"*) ;;
    *) fail "expected output to contain '$1', got: $OUTPUT" ;;
  esac
}

setup_repo_with_worktree() {
  TMPDIR="$(mktemp -d)"
  MAIN="$TMPDIR/main"
  ORIGIN="$TMPDIR/origin.git"
  WORKTREE="$TMPDIR/worktree"

  git init -q -b master "$MAIN"
  git -C "$MAIN" config user.email "test@example.com"
  git -C "$MAIN" config user.name "Test User"
  echo "hello" > "$MAIN/file.txt"
  git -C "$MAIN" add file.txt
  git -C "$MAIN" commit -q -m "Initial commit"

  git init -q --bare "$ORIGIN"
  git -C "$MAIN" remote add origin "$ORIGIN"
  git -C "$MAIN" push -q -u origin master
  git -C "$MAIN" worktree add -q -b feature "$WORKTREE" master
}

test_ignores_non_archive_trigger() {
  run_and_capture env COPILOT_SCRIPT_TRIGGER=session.create bash "$SCRIPT"
  [[ "$STATUS" -eq 0 ]] || fail "non-archive trigger should exit 0"
  [[ -z "$OUTPUT" ]] || fail "non-archive trigger should not output anything"
}

test_skips_main_checkout() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  run_and_capture env \
    COPILOT_SCRIPT_TRIGGER=session.archive \
    COPILOT_WORKSPACE_PATH="$tmp" \
    COPILOT_ROOT_PATH="$tmp" \
    COPILOT_DEFAULT_BRANCH=master \
    bash "$SCRIPT"

  [[ "$STATUS" -eq 0 ]] || fail "main checkout should exit 0"
  assert_output_contains "Skip: main checkout"
}

test_stops_on_dirty_worktree() {
  setup_repo_with_worktree
  trap 'rm -rf "$TMPDIR"' RETURN

  echo "dirty" > "$WORKTREE/dirty.txt"

  run_and_capture env \
    COPILOT_SCRIPT_TRIGGER=session.archive \
    COPILOT_WORKSPACE_PATH="$WORKTREE" \
    COPILOT_ROOT_PATH="$MAIN" \
    COPILOT_DEFAULT_BRANCH=master \
    bash "$SCRIPT"

  [[ "$STATUS" -eq 1 ]] || fail "dirty worktree should exit 1"
  assert_output_contains "Stop: worktree has uncommitted changes"
  [[ -d "$WORKTREE" ]] || fail "dirty worktree should not be removed"
}

test_removes_clean_worktree_when_remote_branch_is_gone_and_merged() {
  setup_repo_with_worktree
  trap 'rm -rf "$TMPDIR"' RETURN

  run_and_capture env \
    COPILOT_SCRIPT_TRIGGER=session.archive \
    COPILOT_WORKSPACE_PATH="$WORKTREE" \
    COPILOT_ROOT_PATH="$MAIN" \
    COPILOT_DEFAULT_BRANCH=master \
    bash "$SCRIPT"

  [[ "$STATUS" -eq 0 ]] || fail "safe worktree cleanup should exit 0: $OUTPUT"
  [[ ! -e "$WORKTREE" ]] || fail "safe worktree should be removed"
  if git -C "$MAIN" show-ref --verify --quiet refs/heads/feature; then
    fail "feature branch should be deleted"
  fi
}

test_ignores_non_archive_trigger
test_skips_main_checkout
test_stops_on_dirty_worktree
test_removes_clean_worktree_when_remote_branch_is_gone_and_merged

echo "cleanup-merged-pr-worktree-on-archive tests passed"
