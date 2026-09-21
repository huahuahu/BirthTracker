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
UPCOMING_BIRTHDAYS_INTENT_FILE="$WIDGET_INTENTS_PACKAGE_DIR/UpcomingBirthdaysConfigurationIntent.swift"
DISPLAY_CALENDAR_FILE="$WIDGET_INTENTS_PACKAGE_DIR/WidgetDisplayCalendar.swift"
DISPLAY_FORMAT_FILE="$WIDGET_INTENTS_PACKAGE_DIR/WidgetAgeDisplayFormat.swift"
WIDGET_PERSON_SELECTION_FILE="$WIDGET_INTENTS_PACKAGE_DIR/WidgetPersonSelection.swift"
TOGGLE_FORMAT_INTENT_FILE="$WIDGET_INTENTS_PACKAGE_DIR/ToggleContactAgeFormatIntent.swift"
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

grep -q 'optionsProvider: ContactAgePersonOptionsProvider()' "$INTENT_FILE" \
  || fail "SelectPersonIntent should persist an instance token with the selected person option"

if grep -q 'IntentParameterDependency<SelectPersonIntent>' "$INTENT_FILE"; then
  fail "SelectPersonIntent person options should not depend on another configuration parameter"
fi

grep -q 'public var widgetInstanceIDValue: String?' "$INTENT_FILE" \
  || fail "SelectPersonIntent should retain compatibility with saved separate instance IDs"

if grep -q 'widgetInstanceIDValue = UUID()' "$INTENT_FILE"; then
  fail "Restoring a widget configuration must not create a new unsaved instance ID"
fi

grep -q 'public var displayCalendar: String?' "$INTENT_FILE" \
  || fail "SelectPersonIntent should persist display calendar as a stable optional String identifier"

grep -q 'optionsProvider: WidgetDisplayCalendarOptionsProvider()' "$INTENT_FILE" \
  || fail "SelectPersonIntent should provide localized options for the display calendar identifier"

grep -q '^public struct SelectUpcomingBirthdaysIntent: WidgetConfigurationIntent' "$UPCOMING_BIRTHDAYS_INTENT_FILE" \
  || fail "Upcoming birthday widgets should use a dedicated configuration intent"

grep -q 'public var ageDisplayFormat: String?' "$INTENT_FILE" \
  || fail "SelectPersonIntent should persist age format as a stable optional String identifier"

grep -q 'optionsProvider: WidgetAgeDisplayFormatOptionsProvider()' "$INTENT_FILE" \
  || fail "SelectPersonIntent should provide localized age format options"

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
  "$UPCOMING_BIRTHDAYS_INTENT_FILE"
  "$DISPLAY_CALENDAR_FILE"
  "$DISPLAY_FORMAT_FILE"
  "$WIDGET_PERSON_SELECTION_FILE"
  "$TOGGLE_FORMAT_INTENT_FILE"
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
grep -q 'dependencies: \["Logging", "Models", "Persistence"\]' "$PACKAGE_FILE" \
  || fail "BirthTrackerWidgetIntents should depend directly on Models for calendar resolution"
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
    "Age Format": {"en": "Age Format", "zh-Hans": "年龄格式"},
    "Buddhist": {"en": "Buddhist", "zh-Hans": "佛历"},
    "Choose Person": {"en": "Choose Person", "zh-Hans": "选择联系人"},
    "Choose which person this widget shows.": {
        "en": "Choose which person this widget shows.",
        "zh-Hans": "选择要展示的联系人",
    },
    "Chinese": {"en": "Chinese", "zh-Hans": "农历"},
    "Contact": {"en": "Contact", "zh-Hans": "联系人"},
    "Days": {"en": "Days", "zh-Hans": "日"},
    "Display Calendar": {"en": "Display Calendar", "zh-Hans": "显示日历"},
    "Follow Contact": {"en": "Follow Contact", "zh-Hans": "跟随联系人"},
    "Gregorian": {"en": "Gregorian", "zh-Hans": "公历"},
    "Hebrew": {"en": "Hebrew", "zh-Hans": "希伯来历"},
    "Islamic": {"en": "Islamic", "zh-Hans": "伊斯兰历"},
    "Months, Days": {"en": "Months, Days", "zh-Hans": "月、日"},
    "Toggle Age Format": {"en": "Toggle Age Format", "zh-Hans": "切换年龄格式"},
    "Widget ID": {"en": "Widget ID", "zh-Hans": "小组件 ID"},
    "Years, Months, Days": {"en": "Years, Months, Days", "zh-Hans": "年、月、日"},
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
    "Gregorian": {"en": "Gregorian", "zh-Hans": "公历"},
    "Chinese": {"en": "Chinese", "zh-Hans": "农历"},
    "Buddhist": {"en": "Buddhist", "zh-Hans": "佛历"},
    "Hebrew": {"en": "Hebrew", "zh-Hans": "希伯来历"},
    "Islamic": {"en": "Islamic", "zh-Hans": "伊斯兰历"},
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

# Omitting bundle uses the main bundle and avoids Xcode 27.1's metadata extraction error.
grep -Fq 'LocalizedStringResource("Choose Person", table: "Intents")' "$INTENT_FILE" \
  || fail "SelectPersonIntent title should use the main-bundle Intents table"
grep -Fq 'LocalizedStringResource("Choose which person this widget shows.", table: "Intents")' "$INTENT_FILE" \
  || fail "SelectPersonIntent description should preserve its original source key"
grep -Fq 'LocalizedStringResource("Contact", table: "Intents")' "$INTENT_FILE" \
  || fail "SelectPersonIntent parameter should preserve the Contact source key"
grep -Fq 'LocalizedStringResource("Display Calendar", table: "Intents")' "$INTENT_FILE" \
  || fail "SelectPersonIntent should expose the localized Display Calendar parameter"
grep -Fq 'WidgetDisplayCalendar(rawValue: displayCalendar ?? "") ?? .followContact' "$INTENT_FILE" \
  || fail "SelectPersonIntent should resolve missing or unknown calendar identifiers as following the contact"
grep -Fq '\.$personID' "$INTENT_FILE" \
  || fail "SelectPersonIntent summary should include the contact parameter"
grep -Fq '\.$displayCalendar' "$INTENT_FILE" \
  || fail "SelectPersonIntent summary should include the display calendar parameter"
person_summary_line="$(grep -nF '\.$personID' "$INTENT_FILE" | head -1 | cut -d: -f1)"
calendar_summary_line="$(grep -nF '\.$displayCalendar' "$INTENT_FILE" | cut -d: -f1)"
[[ "$person_summary_line" -lt "$calendar_summary_line" ]] \
  || fail "SelectPersonIntent summary should place Contact before Display Calendar"
grep -Fq 'public enum WidgetDisplayCalendar: String, AppEnum' "$DISPLAY_CALENDAR_FILE" \
  || fail "Widget display calendar choices should use a fixed AppEnum"
grep -Fq 'public struct WidgetDisplayCalendarOptionsProvider: DynamicOptionsProvider' "$DISPLAY_CALENDAR_FILE" \
  || fail "Widget display calendar should expose localized raw String options across the intent boundary"
grep -Fq 'WidgetDisplayCalendar.followContact.rawValue' "$DISPLAY_CALENDAR_FILE" \
  || fail "Widget display calendar options should default to the stable follow-contact identifier"
for source_key in "Display Calendar" "Follow Contact" Gregorian Chinese Buddhist Hebrew Islamic; do
  grep -Fq "LocalizedStringResource(\"$source_key\", table: \"Intents\")" "$DISPLAY_CALENDAR_FILE" \
    || fail "WidgetDisplayCalendar should localize $source_key through the main-bundle Intents table"
done
grep -Fq 'LocalizedStringResource("Age Format", table: "Intents")' "$INTENT_FILE" \
  || fail "SelectPersonIntent should expose the localized Age Format parameter"
grep -Fq 'LocalizedStringResource("Widget ID", table: "Intents")' "$INTENT_FILE" \
  || fail "SelectPersonIntent should localize its hidden widget instance parameter"
grep -Fq 'IntentItem(selection.rawValue, title:' "$INTENT_FILE" \
  || fail "Contact age person options should save the instance token in their selected value"
grep -Fq 'WidgetPersonSelection(personID: $0, widgetInstanceID: widgetInstanceID).rawValue' "$INTENT_FILE" \
  || fail "Programmatic configurations should save the same encoded person selection as WidgetKit"
if grep -Fq '\.$widgetInstanceIDValue' "$INTENT_FILE"; then
  fail "SelectPersonIntent should keep the widget instance identity out of the configuration UI"
fi
grep -Fq 'public var contactAgeStateID: String?' "$INTENT_FILE" \
  || fail "SelectPersonIntent should expose an instance-aware contact age state ID"
grep -Fq 'WidgetAgeDisplayFormat(rawValue: ageDisplayFormat ?? "") ?? .yearMonthDay' "$INTENT_FILE" \
  || fail "SelectPersonIntent should resolve missing or unknown age formats to years months and days"
if grep -Fq '\.$ageDisplayFormat' "$INTENT_FILE"; then
  fail "Age format is interactive state and must not appear in widget configuration"
fi
grep -Fq '\.$personID' "$UPCOMING_BIRTHDAYS_INTENT_FILE" \
  || fail "SelectUpcomingBirthdaysIntent summary should include the contact parameter"
grep -Fq '\.$displayCalendar' "$UPCOMING_BIRTHDAYS_INTENT_FILE" \
  || fail "SelectUpcomingBirthdaysIntent summary should include the display calendar parameter"
if grep -Fq '\.$ageDisplayFormat' "$UPCOMING_BIRTHDAYS_INTENT_FILE"; then
  fail "SelectUpcomingBirthdaysIntent should not expose the contact age format"
fi
grep -Fq 'public enum WidgetAgeDisplayFormat: String, AppEnum' "$DISPLAY_FORMAT_FILE" \
  || fail "Widget age display format choices should use a fixed AppEnum"
grep -Fq 'public struct WidgetAgeDisplayFormatOptionsProvider: DynamicOptionsProvider' "$DISPLAY_FORMAT_FILE" \
  || fail "Widget age display format should expose localized raw String options"
grep -Fq 'WidgetAgeDisplayFormat.yearMonthDay.rawValue' "$DISPLAY_FORMAT_FILE" \
  || fail "Widget age display format should default to years months and days"
for source_key in "Age Format" "Years, Months, Days" "Months, Days" Days; do
  grep -Fq "LocalizedStringResource(\"$source_key\", table: \"Intents\")" "$DISPLAY_FORMAT_FILE" \
    || fail "WidgetAgeDisplayFormat should localize $source_key through the main-bundle Intents table"
done

grep -Fq 'public struct ToggleContactAgeFormatIntent: AppIntent' "$TOGGLE_FORMAT_INTENT_FILE" \
  || fail "Contact age widgets should retain their interactive format toggle intent"
grep -Fq 'public static let isDiscoverable = false' "$TOGGLE_FORMAT_INTENT_FILE" \
  || fail "The widget-only toggle intent should not appear in system discovery"
if grep -Fq 'reloadTimelines(ofKind:' "$TOGGLE_FORMAT_INTENT_FILE"; then
  fail "The toggle intent should let WidgetKit refresh only the invoking widget instance"
fi
grep -Fq 'Button(' "$CONTACT_AGE_DIR/ContactAgeWidgetView.swift" \
  || fail "ContactAgeWidgetView should remain interactive"
grep -Fq 'ToggleContactAgeFormatIntent(' "$CONTACT_AGE_DIR/ContactAgeWidgetView.swift" \
  || fail "ContactAgeWidgetView should invoke the format toggle intent"

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
grep -q 'product: BirthTrackerWidgetIntents' <<<"$tests_target_block" \
  || fail "BirthTrackerTests should depend on BirthTrackerWidgetIntents when compiling intent tests"
grep -q 'product: BirthTrackerWidgets' <<<"$tests_target_block" \
  || fail "BirthTrackerTests should depend on BirthTrackerWidgets when compiling widget tests"

grep -q '^import BirthTrackerWidgetIntents$' "$APP_ENTRY_FILE" \
  || fail "BirthTrackerApp should import BirthTrackerWidgetIntents"
grep -q '_ = SelectPersonIntent.self' "$APP_ENTRY_FILE" \
  || fail "BirthTrackerApp should register SelectPersonIntent"
grep -q '_ = SelectUpcomingBirthdaysIntent.self' "$APP_ENTRY_FILE" \
  || fail "BirthTrackerApp should register SelectUpcomingBirthdaysIntent"

for intent_consumer in \
  "$CONTACT_AGE_DIR/ContactAgeWidget.swift" \
  "$CONTACT_AGE_DIR/ContactAgeProvider.swift" \
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysWidget.swift" \
  "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysProvider.swift"; do
  grep -q '^import BirthTrackerWidgetIntents$' "$intent_consumer" \
    || fail "$(relative_to_root "$intent_consumer") should import BirthTrackerWidgetIntents"
done

grep -q 'intent: SelectPersonIntent.self' "$CONTACT_AGE_DIR/ContactAgeWidget.swift" \
  || fail "ContactAgeWidget should retain SelectPersonIntent for existing widget compatibility"
grep -q 'configuration: SelectPersonIntent' "$CONTACT_AGE_DIR/ContactAgeProvider.swift" \
  || fail "ContactAgeProvider should consume SelectPersonIntent"
grep -q 'intent: SelectUpcomingBirthdaysIntent.self' "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysWidget.swift" \
  || fail "UpcomingBirthdaysWidget should use its dedicated configuration intent"
grep -q 'configuration: SelectUpcomingBirthdaysIntent' "$UPCOMING_BIRTHDAYS_DIR/UpcomingBirthdaysProvider.swift" \
  || fail "UpcomingBirthdaysProvider should consume SelectUpcomingBirthdaysIntent"

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
