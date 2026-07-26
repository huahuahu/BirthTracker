#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_FILE="$ROOT/BirthTrackerPackage/Package.swift"
PROJECT_FILE="$ROOT/project.yml"
WIDGET_PACKAGE_DIR="$ROOT/BirthTrackerPackage/Sources/BirthTrackerWidgets"
WIDGET_INTENTS_PACKAGE_DIR="$ROOT/BirthTrackerPackage/Sources/BirthTrackerWidgetIntents"
WIDGET_EXTENSION_DIR="$ROOT/Sources/BirthTrackerWidget"
SHARED_DIR="$WIDGET_PACKAGE_DIR/Shared"
CONTACT_AGE_DIR="$WIDGET_PACKAGE_DIR/ContactAge"
UPCOMING_BIRTHDAYS_DIR="$WIDGET_PACKAGE_DIR/UpcomingBirthdays"
WIDGET_RESOURCE_FILE="$WIDGET_PACKAGE_DIR/Resources/Localizable.xcstrings"
APP_INTENTS_FILE="$ROOT/Sources/BirthTrackerApp/Intents.xcstrings"
WIDGET_INTENTS_FILE="$WIDGET_EXTENSION_DIR/Intents.xcstrings"
BASE_REVISION="03ad6a5"
BASE_WIDGET_RESOURCE_PATH="BirthTrackerPackage/Sources/Localization/Resources/Localizable.xcstrings"
CONTACT_AGE_EXTENSION_DIR="$WIDGET_EXTENSION_DIR/ContactAge"
UPCOMING_BIRTHDAYS_EXTENSION_DIR="$WIDGET_EXTENSION_DIR/UpcomingBirthdays"
INTENT_FILE="$WIDGET_INTENTS_PACKAGE_DIR/PersonSelectionIntent.swift"
TOGGLE_INTENT_FILE="$WIDGET_INTENTS_PACKAGE_DIR/ToggleContactAgeFormatIntent.swift"
INTENTS_PACKAGE_FILE="$WIDGET_INTENTS_PACKAGE_DIR/BirthTrackerWidgetIntentsAppIntentsPackage.swift"
APP_ENTRY_FILE="$ROOT/Sources/BirthTrackerApp/BirthTrackerApp.swift"
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
  "$WIDGET_RESOURCE_FILE"
  "$SHARED_DIR/WidgetL10n.swift"
  "$CONTACT_AGE_DIR/ContactAgeDurationFormatter.swift"
  "$CONTACT_AGE_DIR/ContactAgeEntry.swift"
  "$CONTACT_AGE_DIR/ContactAgeProvider.swift"
  "$CONTACT_AGE_DIR/ContactAgeWidget.swift"
  "$CONTACT_AGE_DIR/ContactAgeWidgetPreviews.swift"
  "$CONTACT_AGE_DIR/ContactAgeWidgetView.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysEntry.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysProvider.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysWidget.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysWidgetPreviews.swift"
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysWidgetView.swift"
)

expected_intent_package_files=(
  "$INTENTS_PACKAGE_FILE"
  "$INTENT_FILE"
  "$TOGGLE_INTENT_FILE"
)

expected_extension_files=(
  "$BUNDLE_FILE"
  "$WIDGET_INTENTS_FILE"
)

for file in \
  "${expected_package_files[@]}" \
  "${expected_intent_package_files[@]}" \
  "${expected_extension_files[@]}"; do
  [[ -f "$file" ]] \
    || fail "$(relative_to_root "$file") should exist"
done

for old_intent_file in \
  "$SHARED_DIR/BirthTrackerWidgetsAppIntentsPackage.swift" \
  "$SHARED_DIR/PersonSelectionIntent.swift" \
  "$CONTACT_AGE_DIR/ToggleContactAgeFormatIntent.swift"; do
  [[ ! -e "$old_intent_file" ]] \
    || fail "$(relative_to_root "$old_intent_file") should move to BirthTrackerWidgetIntents"
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
grep -q 'library(name: "BirthTrackerWidgetIntents"' "$PACKAGE_FILE" \
  || fail "Package.swift should expose a BirthTrackerWidgetIntents product"
grep -q 'name: "BirthTrackerWidgets"' "$PACKAGE_FILE" \
  || fail "Package.swift should define a BirthTrackerWidgets target"
grep -q 'name: "BirthTrackerWidgetIntents"' "$PACKAGE_FILE" \
  || fail "Package.swift should define a BirthTrackerWidgetIntents target"
grep -q 'dependencies: \["BirthTrackerWidgetIntents", "Logging", "Models", "Persistence", "SFSafeSymbols"\]' "$PACKAGE_FILE" \
  || fail "BirthTrackerWidgets should depend on BirthTrackerWidgetIntents"
grep -q 'resources: \[.process("Resources")\]' "$PACKAGE_FILE" \
  || fail "BirthTrackerWidgets should process its own localization resources"

if grep -R '^import Localization$' "$WIDGET_PACKAGE_DIR"; then
  fail "Widget UI strings should be owned by BirthTrackerWidgets resources"
fi

python3 - "$ROOT" "$APP_INTENTS_FILE" "$WIDGET_INTENTS_FILE" "$WIDGET_RESOURCE_FILE" \
  "$BASE_REVISION" "$BASE_WIDGET_RESOURCE_PATH" <<'PY' \
  || fail "Widget and AppIntent localization catalogs should preserve pre-migration copy"
import json
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
app_intents_path = Path(sys.argv[2])
widget_intents_path = Path(sys.argv[3])
widget_resource_path = Path(sys.argv[4])
base_revision = sys.argv[5]
base_widget_resource_path = sys.argv[6]


def load_catalog(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise SystemExit(f"{path.relative_to(root)} is not valid JSON: {error}") from error


def localized_value(strings: dict, key: str, locale: str) -> str:
    try:
        return strings[key]["localizations"][locale]["stringUnit"]["value"]
    except KeyError as error:
        raise SystemExit(f"Missing {key!r} {locale} value") from error


app_intents = load_catalog(app_intents_path)
load_catalog(widget_intents_path)
widget_resources = load_catalog(widget_resource_path)

expected_intents = {
    "Choose Person": {"en": "Choose Person", "zh-Hans": "选择联系人"},
    "Choose which person this widget shows.": {
        "en": "Choose which person this widget shows.",
        "zh-Hans": "选择要展示的联系人",
    },
    "Contact": {"en": "Contact", "zh-Hans": "联系人"},
    "Person ID": {"en": "Person ID", "zh-Hans": "Person ID"},
    "Toggle Age Format": {"en": "Toggle Age Format", "zh-Hans": "切换年龄格式"},
}
intent_strings = app_intents.get("strings", {})
if set(intent_strings) != set(expected_intents):
    missing = sorted(set(expected_intents) - set(intent_strings))
    unexpected = sorted(set(intent_strings) - set(expected_intents))
    raise SystemExit(f"AppIntent source keys changed: missing={missing}, unexpected={unexpected}")
for key, localized_values in expected_intents.items():
    for locale, expected_value in localized_values.items():
        actual_value = localized_value(intent_strings, key, locale)
        if actual_value != expected_value:
            raise SystemExit(
                f"AppIntent {key!r} {locale} changed: expected {expected_value!r}, got {actual_value!r}")

app_intents_bytes = app_intents_path.read_bytes()
widget_intents_bytes = widget_intents_path.read_bytes()
if app_intents_bytes != widget_intents_bytes:
    raise SystemExit("App and Widget extension Intents.xcstrings must be byte-identical")

base_bytes = subprocess.check_output(
    ["git", "-C", str(root), "show", f"{base_revision}:{base_widget_resource_path}"])
base_resources = json.loads(base_bytes)
base_strings = base_resources.get("strings", {})
widget_strings = widget_resources.get("strings", {})
expected_widget_keys = {
    "Add a birth year to show age.",
    "Birthdays",
    "Choose a person to show their age.",
    "Contact Age",
    "No birthday recorded",
    "No upcoming birthdays",
    "See the next birthdays at a glance.",
    "Selected person is no longer available.",
    "Tap to switch format",
    "Track one person's current age. Tap to switch formats.",
    "Upcoming Birthdays",
    "person.detail.days.until.birthday.format",
    "widget.birth.duration.format",
    "widget.contact.age.format.duration",
    "widget.contact.age.format.month.day",
    "widget.contact.age.format.total.days",
}
new_widget_strings = {
    "Since birth": {"en": "Since birth", "zh-Hans": "出生至今"},
}
all_expected_widget_keys = expected_widget_keys | set(new_widget_strings)
if set(widget_strings) != all_expected_widget_keys:
    missing = sorted(all_expected_widget_keys - set(widget_strings))
    unexpected = sorted(set(widget_strings) - all_expected_widget_keys)
    raise SystemExit(f"Widget UI source keys changed: missing={missing}, unexpected={unexpected}")
for key in sorted(expected_widget_keys):
    for locale in ("en", "zh-Hans"):
        expected_value = localized_value(base_strings, key, locale)
        actual_value = localized_value(widget_strings, key, locale)
        if actual_value != expected_value:
            raise SystemExit(
                f"Widget UI {key!r} {locale} changed: expected {expected_value!r}, got {actual_value!r}")
for key, localized_values in new_widget_strings.items():
    for locale, expected_value in localized_values.items():
        actual_value = localized_value(widget_strings, key, locale)
        if actual_value != expected_value:
            raise SystemExit(
                f"Widget UI {key!r} {locale} changed: expected {expected_value!r}, got {actual_value!r}")
PY

grep -Fq 'LocalizedStringResource("Choose Person", table: "Intents", bundle: .main)' "$INTENT_FILE" \
  || fail "SelectPersonIntent title should use the main-bundle Intents table"
grep -Fq 'LocalizedStringResource("Choose which person this widget shows.", table: "Intents", bundle: .main)' "$INTENT_FILE" \
  || fail "SelectPersonIntent description should preserve its original source key"
grep -Fq 'LocalizedStringResource("Contact", table: "Intents", bundle: .main)' "$INTENT_FILE" \
  || fail "SelectPersonIntent parameter should preserve the Contact source key"
grep -Fq 'LocalizedStringResource("Toggle Age Format", table: "Intents", bundle: .main)' "$TOGGLE_INTENT_FILE" \
  || fail "ToggleContactAgeFormatIntent title should use the main-bundle Intents table"
grep -Fq 'LocalizedStringResource("Person ID", table: "Intents", bundle: .main)' "$TOGGLE_INTENT_FILE" \
  || fail "ToggleContactAgeFormatIntent parameter should preserve the Person ID source key"
grep -q '^public struct ToggleContactAgeFormatIntent: AppIntent' "$TOGGLE_INTENT_FILE" \
  || fail "ToggleContactAgeFormatIntent should be public across the module boundary"

app_target_block="$(awk '/^  BirthTracker:$/,/^  BirthTrackerWidget:$/' "$PROJECT_FILE")"
grep -q 'product: BirthTrackerWidgetIntents' <<<"$app_target_block" \
  || fail "BirthTracker app should depend on BirthTrackerWidgetIntents"
if grep -q 'product: BirthTrackerWidgets' <<<"$app_target_block"; then
  fail "BirthTracker app should not depend on BirthTrackerWidgets"
fi

widget_target_block="$(awk '/^  BirthTrackerWidget:$/,/^  BirthTrackerTests:$/' "$PROJECT_FILE")"
grep -q 'product: BirthTrackerWidgets' <<<"$widget_target_block" \
  || fail "Widget extension should depend on BirthTrackerWidgets"
grep -q 'product: BirthTrackerWidgetIntents' <<<"$widget_target_block" \
  || fail "Widget extension should depend on BirthTrackerWidgetIntents"
if grep -q 'product: Logging' <<<"$widget_target_block"; then
  fail "Widget extension should not directly depend on Logging"
fi

tests_target_block="$(awk '/^  BirthTrackerTests:$/,/^schemes:/' "$PROJECT_FILE")"
grep -q 'product: BirthTrackerWidgets' <<<"$tests_target_block" \
  || fail "BirthTrackerTests should depend on BirthTrackerWidgets when compiling widget tests"

grep -q '^import BirthTrackerWidgetIntents$' "$APP_ENTRY_FILE" \
  || fail "BirthTrackerApp should import BirthTrackerWidgetIntents"

for intent_consumer in \
  "$CONTACT_AGE_DIR/ContactAgeWidget.swift" \
  "$CONTACT_AGE_DIR/ContactAgeProvider.swift" \
  "$CONTACT_AGE_DIR/ContactAgeWidgetView.swift" \
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysWidget.swift" \
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysProvider.swift"; do
  grep -q '^import BirthTrackerWidgetIntents$' "$intent_consumer" \
    || fail "$(relative_to_root "$intent_consumer") should import BirthTrackerWidgetIntents"
done

grep -q 'import BirthTrackerWidgets' "$BUNDLE_FILE" \
  || fail "BirthTrackerWidgetBundle should import BirthTrackerWidgets"
grep -q 'BirthTrackerWidgetsBundle().body' "$BUNDLE_FILE" \
  || fail "BirthTrackerWidgetBundle should delegate to the package-owned BirthTrackerWidgetsBundle"
grep -q 'public struct BirthTrackerWidgetsBundle: WidgetBundle' "$PACKAGE_BUNDLE_FILE" \
  || fail "BirthTrackerWidgets should expose a public WidgetBundle"
grep -q 'public init()' "$PACKAGE_BUNDLE_FILE" \
  || fail "BirthTrackerWidgetsBundle should expose a public initializer"
grep -q 'public var body: some Widget' "$PACKAGE_BUNDLE_FILE" \
  || fail "BirthTrackerWidgetsBundle should expose a public body"
grep -q 'UpcomingBirthdaysWidget()' "$PACKAGE_BUNDLE_FILE" \
  || fail "BirthTrackerWidgetsBundle should include the upcoming birthdays widget"
grep -q 'ContactAgeWidget()' "$PACKAGE_BUNDLE_FILE" \
  || fail "BirthTrackerWidgetsBundle should include the contact age widget"

while IFS= read -r swift_file; do
  [[ "$swift_file" == "$BUNDLE_FILE" ]] \
    || fail "$(relative_to_root "$swift_file") should not contain Widget implementation code; keep only the extension shell"
done < <(find "$WIDGET_EXTENSION_DIR" -type f -name '*.swift')

expected_extension_entries="$(
  printf '%s\n' \
    'BirthTrackerWidgetBundle.swift' \
    'Info.plist' \
    'InfoPlist.xcstrings' \
    'Intents.xcstrings' \
    | LC_ALL=C sort
)"
actual_extension_entries="$(
  find "$WIDGET_EXTENSION_DIR" -type f -print \
    | sed "s|^$WIDGET_EXTENSION_DIR/||" \
    | LC_ALL=C sort
)"
[[ "$actual_extension_entries" == "$expected_extension_entries" ]] \
  || fail "Sources/BirthTrackerWidget should contain exactly the shell, Info.plist, InfoPlist.xcstrings, and Intents.xcstrings"

[[ ! -e "$WIDGET_EXTENSION_DIR/Localizable.xcstrings" ]] \
  || fail "Sources/BirthTrackerWidget/Localizable.xcstrings should not exist"

echo "widget person intent storage and package structure tests passed"
