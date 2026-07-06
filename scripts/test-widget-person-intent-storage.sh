#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_FILE="$ROOT/BirthTrackerPackage/Package.swift"
PROJECT_FILE="$ROOT/project.yml"
WIDGET_PACKAGE_DIR="$ROOT/BirthTrackerPackage/Sources/BirthTrackerWidgets"
WIDGET_EXTENSION_DIR="$ROOT/Sources/BirthTrackerWidget"
SHARED_DIR="$WIDGET_PACKAGE_DIR/Shared"
CONTACT_AGE_DIR="$WIDGET_PACKAGE_DIR/ContactAge"
UPCOMING_BIRTHDAYS_DIR="$WIDGET_PACKAGE_DIR/UpcomingBirthdays"
INTENT_FILE="$SHARED_DIR/PersonSelectionIntent.swift"
BUNDLE_FILE="$WIDGET_EXTENSION_DIR/BirthTrackerWidgetBundle.swift"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

grep -q 'var person: WidgetPersonEntity?' "$INTENT_FILE" \
  || fail "SelectPersonIntent should expose WidgetPersonEntity so WidgetKit shows the edit UI"

grep -q 'struct WidgetPersonEntity: AppEntity' "$INTENT_FILE" \
  || fail "WidgetPersonEntity should be a registered AppEntity for Widget configuration"

grep -q 'selectedPersonID' "$INTENT_FILE" \
  || fail "SelectPersonIntent should expose a UUID accessor for provider code"

if grep -R 'configuration\.person' "$CONTACT_AGE_DIR" "$UPCOMING_BIRTHDAYS_DIR"; then
  fail "Widget providers should read selectedPersonID instead of storing person entities"
fi

expected_files=(
  "$SHARED_DIR/BirthTrackerWidgetsAppIntentsPackage.swift"
  "$SHARED_DIR/PersonSelectionIntent.swift"
  "$CONTACT_AGE_DIR/ContactAgeEntry.swift"
  "$CONTACT_AGE_DIR/ContactAgeProvider.swift"
  "$CONTACT_AGE_DIR/ContactAgeWidget.swift"
  "$CONTACT_AGE_DIR/ContactAgeWidgetPreviews.swift"
  "$CONTACT_AGE_DIR/ContactAgeWidgetView.swift"
  "$CONTACT_AGE_DIR/ToggleContactAgeFormatIntent.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysEntry.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysProvider.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysWidget.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysWidgetPreviews.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysWidgetView.swift"
)

for file in "${expected_files[@]}"; do
  [[ -f "$file" ]] \
    || fail "$(realpath --relative-to "$ROOT" "$file") should exist"
done

for file in ContactAgeWidget.swift UpcomingBirthdaysWidget.swift PersonSelectionIntent.swift ToggleContactAgeFormatIntent.swift; do
  [[ ! -f "$WIDGET_PACKAGE_DIR/$file" ]] \
    || fail "$file should be organized under a feature or shared subdirectory"
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
