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

  if ! command -v awk >/dev/null 2>&1; then
    echo "error: awk is required to read .xcodebuildmcp/config.yaml." >&2
    return 127
  fi

  awk -v key="$1:" '$1 == key { print $2; exit }' "$WORKSPACE_PATH/.xcodebuildmcp/config.yaml"
}

hash_text() {
  if command -v md5 >/dev/null 2>&1; then
    printf '%s' "$1" | md5 -q
  elif command -v md5sum >/dev/null 2>&1; then
    if MD5SUM_OUTPUT="$(printf '%s' "$1" | md5sum)"; then
      printf '%s\n' "${MD5SUM_OUTPUT%% *}"
    else
      MD5SUM_STATUS=$?
      return "$MD5SUM_STATUS"
    fi
  else
    echo "error: md5 or md5sum is required to compute xcode-build-server cache paths." >&2
    exit 127
  fi
}

build_server_compile_file_path() {
  if ! command -v sed >/dev/null 2>&1; then
    echo "error: sed is required to compute xcode-build-server cache paths." >&2
    return 127
  fi

  if CACHE_ROOT_KEY="$(printf '%s' "$WORKSPACE_PATH" | sed 's#/#-#g')"; then
    :
  else
    CACHE_ROOT_KEY_STATUS=$?
    return "$CACHE_ROOT_KEY_STATUS"
  fi
  if BUILD_ROOT_HASH="$(hash_text "$BUILD_ROOT")"; then
    :
  else
    BUILD_ROOT_HASH_STATUS=$?
    return "$BUILD_ROOT_HASH_STATUS"
  fi
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

  if BUILD_WORKSPACE="$(read_build_server_value workspace)"; then
    :
  else
    BUILD_WORKSPACE_STATUS=$?
    echo "error: buildServer.json is missing a workspace value." >&2
    exit "$BUILD_WORKSPACE_STATUS"
  fi

  if BUILD_SCHEME="$(read_build_server_value scheme)"; then
    :
  else
    BUILD_SCHEME_STATUS=$?
    echo "error: buildServer.json is missing a scheme value." >&2
    exit "$BUILD_SCHEME_STATUS"
  fi

  if BUILD_ROOT="$(read_build_server_value build_root)"; then
    :
  else
    BUILD_ROOT_STATUS=$?
    echo "error: buildServer.json is missing a build_root value." >&2
    exit "$BUILD_ROOT_STATUS"
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
  if SIMULATOR_ID="$(read_xcodebuildmcp_session_default simulatorId)"; then
    :
  else
    SIMULATOR_ID_STATUS=$?
    return "$SIMULATOR_ID_STATUS"
  fi
  if [ -n "$SIMULATOR_ID" ]; then
    BUILD_DESTINATION="platform=iOS Simulator,id=$SIMULATOR_ID"
  fi

  RESULT_BUNDLE_PATH="$WORKSPACE_PATH/AIOutput/BuildServer.xcresult"
  rm -rf "$RESULT_BUNDLE_PATH"

  if COMPILE_FILE="$(build_server_compile_file_path)"; then
    :
  else
    COMPILE_FILE_STATUS=$?
    return "$COMPILE_FILE_STATUS"
  fi
  COMPILE_FILE_PARENT=${COMPILE_FILE%/*}
  mkdir -p "$COMPILE_FILE_PARENT"
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
