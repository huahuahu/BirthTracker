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
