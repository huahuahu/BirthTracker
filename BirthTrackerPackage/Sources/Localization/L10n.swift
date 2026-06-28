import Foundation

public enum L10n {

  public static func string(_ resource: LocalizedStringResource) -> String {
    String(localized: resource)
  }

  public enum Common {
    public static let birthdays = LocalizedStringResource("Birthdays", bundle: .atURL(Bundle.module.bundleURL))
    public static let calendar = LocalizedStringResource("Calendar", bundle: .atURL(Bundle.module.bundleURL))
    public static let cancel = LocalizedStringResource("Cancel", bundle: .atURL(Bundle.module.bundleURL))
    public static let ok = LocalizedStringResource("OK", bundle: .atURL(Bundle.module.bundleURL))
    public static let retry = LocalizedStringResource("Retry", bundle: .atURL(Bundle.module.bundleURL))
    public static let save = LocalizedStringResource("Save", bundle: .atURL(Bundle.module.bundleURL))
    public static let settings = LocalizedStringResource("Settings", bundle: .atURL(Bundle.module.bundleURL))
  }

  public enum Timeline {
    public static let addPerson = LocalizedStringResource("Add Person", bundle: .atURL(Bundle.module.bundleURL))
    public static let emptyDescription = LocalizedStringResource(
      "Add a person to start the timeline.", bundle: .atURL(Bundle.module.bundleURL))
    public static let noBirthdays = LocalizedStringResource("No Birthdays", bundle: .atURL(Bundle.module.bundleURL))
    public static let people = LocalizedStringResource("People", bundle: .atURL(Bundle.module.bundleURL))
    public static let upcoming = LocalizedStringResource("Upcoming", bundle: .atURL(Bundle.module.bundleURL))

    public static func ageAccessibilityLabel(_ age: Int) -> String {
      let format = L10n.string(
        LocalizedStringResource("birthday.age.accessibility.format", bundle: .atURL(Bundle.module.bundleURL)))
      return String.localizedStringWithFormat(format, age)
    }
  }

  public enum PersonForm {
    public static let addBirthday = LocalizedStringResource("Add Birthday", bundle: .atURL(Bundle.module.bundleURL))
    public static let birthDate = LocalizedStringResource("Birth date", bundle: .atURL(Bundle.module.bundleURL))
    public static let birthday = LocalizedStringResource("Birthday", bundle: .atURL(Bundle.module.bundleURL))
    public static let name = LocalizedStringResource("Name", bundle: .atURL(Bundle.module.bundleURL))
    public static let notes = LocalizedStringResource("Notes", bundle: .atURL(Bundle.module.bundleURL))
    public static let person = LocalizedStringResource("Person", bundle: .atURL(Bundle.module.bundleURL))
  }

  public enum Settings {
    public static let appearance = LocalizedStringResource("Appearance", bundle: .atURL(Bundle.module.bundleURL))
    public static let database = LocalizedStringResource("Database", bundle: .atURL(Bundle.module.bundleURL))
    public static let debug = LocalizedStringResource("Debug", bundle: .atURL(Bundle.module.bundleURL))
    public static let mode = LocalizedStringResource("Mode", bundle: .atURL(Bundle.module.bundleURL))
    public static let resetTestData = LocalizedStringResource(
      "Reset Test Data", bundle: .atURL(Bundle.module.bundleURL))
    public static let resettingTestData = LocalizedStringResource(
      "Resetting Test Data…", bundle: .atURL(Bundle.module.bundleURL))
    public static let storageRestartRequiredMessage = LocalizedStringResource(
      "Storage location updated. Restart the app to use it.", bundle: .atURL(Bundle.module.bundleURL))
    public static let storageRestartRequiredTitle = LocalizedStringResource(
      "Restart Required", bundle: .atURL(Bundle.module.bundleURL))
    public static let testDataReset = LocalizedStringResource(
      "Test Data Reset", bundle: .atURL(Bundle.module.bundleURL))
    public static let testDataResetFailedTitle = LocalizedStringResource(
      "Test Data Reset Failed", bundle: .atURL(Bundle.module.bundleURL))
    public static let title = Common.settings

    public static func testDataResetFailedMessage(_ reason: String) -> String {
      let format = L10n.string(
        LocalizedStringResource("Reset failed: %@", bundle: .atURL(Bundle.module.bundleURL)))
      return String.localizedStringWithFormat(format, reason)
    }
  }

  public enum Appearance {
    public static let dark = LocalizedStringResource("appearance.mode.dark", bundle: .atURL(Bundle.module.bundleURL))
    public static let light = LocalizedStringResource("appearance.mode.light", bundle: .atURL(Bundle.module.bundleURL))
    public static let system = LocalizedStringResource(
      "appearance.mode.system", bundle: .atURL(Bundle.module.bundleURL))
  }

  public enum CalendarKind {
    public static let buddhist = LocalizedStringResource(
      "calendar.kind.buddhist", bundle: .atURL(Bundle.module.bundleURL))
    public static let chinese = LocalizedStringResource(
      "calendar.kind.chinese", bundle: .atURL(Bundle.module.bundleURL))
    public static let gregorian = LocalizedStringResource(
      "calendar.kind.gregorian", bundle: .atURL(Bundle.module.bundleURL))
    public static let hebrew = LocalizedStringResource("calendar.kind.hebrew", bundle: .atURL(Bundle.module.bundleURL))
    public static let islamic = LocalizedStringResource(
      "calendar.kind.islamic", bundle: .atURL(Bundle.module.bundleURL))
  }

  public enum DebugStorage {
    public static let cloud = LocalizedStringResource("debug.storage.cloud", bundle: .atURL(Bundle.module.bundleURL))
    public static let local = LocalizedStringResource("debug.storage.local", bundle: .atURL(Bundle.module.bundleURL))
    public static let memory = LocalizedStringResource("debug.storage.memory", bundle: .atURL(Bundle.module.bundleURL))
  }

  public enum Widget {
    public static let choosePerson = LocalizedStringResource("Choose Person", bundle: .atURL(Bundle.module.bundleURL))
    public static let choosePersonDescription = LocalizedStringResource(
      "Choose which person's birthday this widget shows.", bundle: .atURL(Bundle.module.bundleURL))
    public static let description = LocalizedStringResource(
      "See the next birthdays at a glance.", bundle: .atURL(Bundle.module.bundleURL))
    public static let noUpcomingBirthdays = LocalizedStringResource(
      "No upcoming birthdays", bundle: .atURL(Bundle.module.bundleURL))
    public static let person = LocalizedStringResource("Person", bundle: .atURL(Bundle.module.bundleURL))
    public static let selectedPersonUnavailable = LocalizedStringResource(
      "Selected person is no longer available.", bundle: .atURL(Bundle.module.bundleURL))
    public static let title = LocalizedStringResource("Birthdays", bundle: .atURL(Bundle.module.bundleURL))
    public static let upcomingBirthdays = LocalizedStringResource(
      "Upcoming Birthdays", bundle: .atURL(Bundle.module.bundleURL))
  }
}
