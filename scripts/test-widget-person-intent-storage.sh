#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_FILE="$ROOT/BirthTrackerPackage/Package.swift"
PROJECT_FILE="$ROOT/project.yml"
WIDGET_PACKAGE_DIR="$ROOT/BirthTrackerPackage/Sources/BirthTrackerWidgets"
WIDGET_EXTENSION_DIR="$ROOT/Sources/BirthTrackerWidget"
INTENT_FILE="$WIDGET_PACKAGE_DIR/PersonSelectionIntent.swift"
BUNDLE_FILE="$WIDGET_EXTENSION_DIR/BirthTrackerWidgetBundle.swift"

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

for file in ContactAgeWidget.swift UpcomingBirthdaysWidget.swift PersonSelectionIntent.swift ToggleContactAgeFormatIntent.swift; do
  [[ -f "$WIDGET_PACKAGE_DIR/$file" ]] \
    || fail "$file should live in the BirthTrackerWidgets package target"
  [[ ! -f "$WIDGET_EXTENSION_DIR/$file" ]] \
    || fail "$file should not live in the Widget extension target"
done

grep -q 'library(name: "BirthTrackerWidgets"' "$PACKAGE_FILE" \
  || fail "Package.swift should expose a BirthTrackerWidgets product"
grep -q 'name: "BirthTrackerWidgets"' "$PACKAGE_FILE" \
  || fail "Package.swift should define a BirthTrackerWidgets target"
grep -q 'product: BirthTrackerWidgets' "$PROJECT_FILE" \
  || fail "project.yml should make the Widget extension depend on BirthTrackerWidgets"
grep -q 'import BirthTrackerWidgets' "$BUNDLE_FILE" \
  || fail "BirthTrackerWidgetBundle should import BirthTrackerWidgets"

echo "widget person intent storage and package structure tests passed"
