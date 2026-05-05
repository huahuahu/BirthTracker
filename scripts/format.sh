#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v swift-format >/dev/null 2>&1; then
  echo "error: swift-format is not installed. Install it with: brew install swift-format" >&2
  exit 127
fi

swift-format format \
  --in-place \
  --recursive \
  --parallel \
  --configuration "$ROOT/.swift-format" \
  "$ROOT/Sources" \
  "$ROOT/Tests"
