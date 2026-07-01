#!/bin/sh
set -eu

TRIGGER="${COPILOT_SCRIPT_TRIGGER:-session.create}"

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

if [ "$WORKSPACE_PATH" = "$ROOT_PATH" ]; then
  echo "copilot-session-create: main checkout detected; no config copy needed."
  exit 0
fi

run_xcodegen() {
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen is required to generate BirthTracker.xcodeproj." >&2
    exit 127
  fi

  echo "copilot-session-create: running xcodegen generate."
  (cd "$WORKSPACE_PATH" && xcodegen generate)
}

TARGET_DIR="$WORKSPACE_PATH/Config"
TARGET_CONFIG="$TARGET_DIR/Project.xcconfig"
MAIN_CONFIG="$ROOT_PATH/Config/Project.xcconfig"
EXAMPLE_CONFIG="$ROOT_PATH/Config/Project.xcconfig.example"

if [ -f "$TARGET_CONFIG" ]; then
  echo "copilot-session-create: Config/Project.xcconfig already exists; leaving it unchanged."
elif [ -f "$MAIN_CONFIG" ]; then
  mkdir -p "$TARGET_DIR"
  cp -p "$MAIN_CONFIG" "$TARGET_CONFIG"
  echo "copilot-session-create: copied local Config/Project.xcconfig into the workspace."
elif [ -f "$EXAMPLE_CONFIG" ]; then
  mkdir -p "$TARGET_DIR"
  cp -p "$EXAMPLE_CONFIG" "$TARGET_CONFIG"
  echo "copilot-session-create: copied Config/Project.xcconfig.example into the workspace; update local signing values before building for device or release."
else
  echo "error: neither Config/Project.xcconfig nor Config/Project.xcconfig.example exists under COPILOT_ROOT_PATH." >&2
  exit 1
fi

run_xcodegen
