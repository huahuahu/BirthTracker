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
CONTACT_AGE_EXTENSION_DIR="$WIDGET_EXTENSION_DIR/ContactAge"
UPCOMING_BIRTHDAYS_EXTENSION_DIR="$WIDGET_EXTENSION_DIR/UpcomingBirthdays"
INTENT_FILE="$SHARED_DIR/PersonSelectionIntent.swift"
BUNDLE_FILE="$WIDGET_EXTENSION_DIR/BirthTrackerWidgetBundle.swift"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

grep -q 'var personID: String?' "$INTENT_FILE" \
  || fail "SelectPersonIntent should persist a primitive String personID parameter"

grep -q 'optionsProvider: WidgetPersonOptionsProvider()' "$INTENT_FILE" \
  || fail "SelectPersonIntent should provide dynamic person options for the String personID parameter"

if grep -q 'WidgetPersonEntity' "$INTENT_FILE"; then
  fail "SelectPersonIntent should not use WidgetPersonEntity because WidgetKit fails to persist its EntityIdentifier"
fi

grep -q 'selectedPersonID' "$INTENT_FILE" \
  || fail "SelectPersonIntent should expose a UUID accessor for provider code"

if grep -R 'configuration\.person' "$CONTACT_AGE_EXTENSION_DIR" "$UPCOMING_BIRTHDAYS_EXTENSION_DIR"; then
  fail "Widget providers should read selectedPersonID instead of storing person entities"
fi

expected_package_files=(
  "$SHARED_DIR/BirthTrackerWidgetsAppIntentsPackage.swift"
  "$SHARED_DIR/PersonSelectionIntent.swift"
  "$SHARED_DIR/WidgetLogger.swift"
  "$CONTACT_AGE_DIR/ContactAgeDurationFormatter.swift"
  "$CONTACT_AGE_DIR/ContactAgeWidgetView.swift"
  "$CONTACT_AGE_DIR/ToggleContactAgeFormatIntent.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysWidgetView.swift"
)

expected_extension_files=(
  "$BUNDLE_FILE"
  "$CONTACT_AGE_EXTENSION_DIR/ContactAgeEntry.swift"
  "$CONTACT_AGE_EXTENSION_DIR/ContactAgeProvider.swift"
  "$CONTACT_AGE_EXTENSION_DIR/ContactAgeWidget.swift"
  "$CONTACT_AGE_EXTENSION_DIR/ContactAgeWidgetPreviews.swift"
  "$UPCOMING_BIRTHDAYS_EXTENSION_DIR/UpcomingBirthdaysEntry.swift"
  "$UPCOMING_BIRTHDAYS_EXTENSION_DIR/UpcomingBirthdaysProvider.swift"
  "$UPCOMING_BIRTHDAYS_EXTENSION_DIR/UpcomingBirthdaysWidget.swift"
  "$UPCOMING_BIRTHDAYS_EXTENSION_DIR/UpcomingBirthdaysWidgetPreviews.swift"
)

for file in "${expected_package_files[@]}" "${expected_extension_files[@]}"; do
  [[ -f "$file" ]] \
    || fail "$(realpath --relative-to "$ROOT" "$file") should exist"
done

for file in ContactAgeWidget.swift ContactAgeProvider.swift ContactAgeEntry.swift ContactAgeWidgetPreviews.swift; do
  [[ ! -f "$WIDGET_PACKAGE_DIR/$file" ]] \
    || fail "$file should be organized under a feature or shared subdirectory"
  [[ ! -f "$CONTACT_AGE_DIR/$file" ]] \
    || fail "$file should live in the Widget extension target"
done

for file in UpcomingBirthdaysWidget.swift UpcomingBirthdaysProvider.swift UpcomingBirthdaysEntry.swift UpcomingBirthdaysWidgetPreviews.swift; do
  [[ ! -f "$WIDGET_PACKAGE_DIR/$file" ]] \
    || fail "$file should be organized under a feature or shared subdirectory"
  [[ ! -f "$UPCOMING_BIRTHDAYS_DIR/$file" ]] \
    || fail "$file should live in the Widget extension target"
done

for file in PersonSelectionIntent.swift ToggleContactAgeFormatIntent.swift; do
  [[ ! -f "$WIDGET_PACKAGE_DIR/$file" ]] \
    || fail "$file should be organized under a feature or shared subdirectory"
  [[ ! -f "$WIDGET_EXTENSION_DIR/$file" ]] \
    || fail "$file should not live at the Widget extension root"
done

grep -q 'library(name: "BirthTrackerWidgets"' "$PACKAGE_FILE" \
  || fail "Package.swift should expose a BirthTrackerWidgets product"
grep -q 'name: "BirthTrackerWidgets"' "$PACKAGE_FILE" \
  || fail "Package.swift should define a BirthTrackerWidgets target"
grep -q 'product: BirthTrackerWidgets' "$PROJECT_FILE" \
  || fail "project.yml should make the Widget extension depend on BirthTrackerWidgets"
awk '/^  BirthTracker:$/,/^  BirthTrackerWidget:$/' "$PROJECT_FILE" | grep -q 'product: BirthTrackerWidgets' \
  || fail "project.yml should make the host app depend on BirthTrackerWidgets so AppIntents can instantiate Widget configuration intents"
awk '/^  BirthTrackerWidget:$/,/^  BirthTrackerTests:$/' "$PROJECT_FILE" | grep -q 'product: BirthTrackerWidgets' \
  || fail "project.yml should make the Widget extension depend on BirthTrackerWidgets"
grep -q 'import BirthTrackerWidgets' "$BUNDLE_FILE" \
  || fail "BirthTrackerWidgetBundle should import BirthTrackerWidgets"

echo "widget person intent storage and package structure tests passed"
