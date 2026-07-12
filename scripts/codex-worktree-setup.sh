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

case "$0" in
*/*)
  SCRIPT_DIR=${0%/*}
  if [ -z "$SCRIPT_DIR" ]; then
    SCRIPT_DIR=/
  fi
  ;;
*)
  SCRIPT_DIR=.
  ;;
esac
SCRIPT_DIR="$(CDPATH= cd "$SCRIPT_DIR" && pwd -P)"

exec "$SCRIPT_DIR/worktree-setup.sh" \
  "$ROOT_PATH" \
  "$WORKSPACE_PATH" \
  "codex-worktree-setup.log" \
  "codex-worktree-setup"
