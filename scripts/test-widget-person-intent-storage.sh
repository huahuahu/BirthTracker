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
PACKAGE_BUNDLE_FILE="$WIDGET_PACKAGE_DIR/BirthTrackerWidgetsBundle.swift"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

relative_to_root() {
  local path="$1"
  case "$path" in
    "$ROOT"/*) printf '%s\n' "${path#"$ROOT"/}" ;;
    *) printf '%s\n' "$path" ;;
  esac
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

if grep -R 'configuration\.person' "$CONTACT_AGE_DIR" "$UPCOMING_BIRTHDAYS_DIR"; then
  fail "Widget providers should read selectedPersonID instead of storing person entities"
fi

expected_package_files=(
  "$PACKAGE_BUNDLE_FILE"
  "$SHARED_DIR/BirthTrackerWidgetsAppIntentsPackage.swift"
  "$SHARED_DIR/PersonSelectionIntent.swift"
  "$CONTACT_AGE_DIR/ContactAgeDurationFormatter.swift"
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

expected_extension_files=(
  "$BUNDLE_FILE"
)

for file in "${expected_package_files[@]}" "${expected_extension_files[@]}"; do
  [[ -f "$file" ]] \
    || fail "$(relative_to_root "$file") should exist"
done

[[ ! -f "$SHARED_DIR/WidgetLogger.swift" ]] \
  || fail "Widget logging should use the shared Logging package instead of WidgetLogger.swift"

for file in ContactAgeWidget.swift ContactAgeProvider.swift ContactAgeEntry.swift ContactAgeWidgetPreviews.swift; do
  [[ ! -f "$WIDGET_PACKAGE_DIR/$file" ]] \
    || fail "$file should be organized under a feature or shared subdirectory"
  [[ ! -f "$CONTACT_AGE_EXTENSION_DIR/$file" ]] \
    || fail "$file should not remain in the Widget extension target"
done

for file in UpcomingBirthdaysWidget.swift UpcomingBirthdaysProvider.swift UpcomingBirthdaysEntry.swift UpcomingBirthdaysWidgetPreviews.swift; do
  [[ ! -f "$WIDGET_PACKAGE_DIR/$file" ]] \
    || fail "$file should be organized under a feature or shared subdirectory"
  [[ ! -f "$UPCOMING_BIRTHDAYS_EXTENSION_DIR/$file" ]] \
    || fail "$file should not remain in the Widget extension target"
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
grep -q 'BirthTrackerWidgetsBundle().body' "$BUNDLE_FILE" \
  || fail "BirthTrackerWidgetBundle should delegate to the package-owned BirthTrackerWidgetsBundle"
grep -q 'public struct BirthTrackerWidgetsBundle: WidgetBundle' "$PACKAGE_BUNDLE_FILE" \
  || fail "BirthTrackerWidgets should expose a public WidgetBundle"
grep -q 'UpcomingBirthdaysWidget()' "$PACKAGE_BUNDLE_FILE" \
  || fail "BirthTrackerWidgetsBundle should include the upcoming birthdays widget"
grep -q 'ContactAgeWidget()' "$PACKAGE_BUNDLE_FILE" \
  || fail "BirthTrackerWidgetsBundle should include the contact age widget"

while IFS= read -r swift_file; do
  [[ "$swift_file" == "$BUNDLE_FILE" ]] \
    || fail "$(relative_to_root "$swift_file") should not contain Widget implementation code; keep only the extension shell"
done < <(find "$WIDGET_EXTENSION_DIR" -type f -name '*.swift')

echo "widget person intent storage and package structure tests passed"
