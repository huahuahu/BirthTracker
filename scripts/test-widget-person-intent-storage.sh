#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INTENT_FILE="$ROOT/Sources/BirthTrackerWidget/PersonSelectionIntent.swift"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

grep -q 'var personID: String?' "$INTENT_FILE" \
  || fail "SelectPersonIntent should persist a String personID parameter"

if grep -q 'var person: WidgetPersonEntity?' "$INTENT_FILE"; then
  fail "SelectPersonIntent should not persist WidgetPersonEntity directly"
fi

grep -q 'selectedPersonID' "$INTENT_FILE" \
  || fail "SelectPersonIntent should expose a UUID parser for the persisted personID"

echo "widget person intent storage tests passed"
