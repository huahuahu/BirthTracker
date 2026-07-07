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
    public static let editPerson = LocalizedStringResource("Edit Person", bundle: .atURL(Bundle.module.bundleURL))
    public static let knownBirthYear = LocalizedStringResource(
      "Known birth year", bundle: .atURL(Bundle.module.bundleURL))
    public static let name = LocalizedStringResource("Name", bundle: .atURL(Bundle.module.bundleURL))
    public static let nameRequired = LocalizedStringResource(
      "Name is required.", bundle: .atURL(Bundle.module.bundleURL))
    public static let notes = LocalizedStringResource("Notes", bundle: .atURL(Bundle.module.bundleURL))
    public static let person = LocalizedStringResource("Person", bundle: .atURL(Bundle.module.bundleURL))
    public static let relationshipGender = LocalizedStringResource(
      "Relationship gender", bundle: .atURL(Bundle.module.bundleURL))
    public static let saveFailedTitle = LocalizedStringResource(
      "Unable to Save", bundle: .atURL(Bundle.module.bundleURL))
  }

  public enum PersonDetail {
    public static let bornFor = LocalizedStringResource("Born for", bundle: .atURL(Bundle.module.bundleURL))
    public static let birthDate = LocalizedStringResource("Birth date", bundle: .atURL(Bundle.module.bundleURL))
    public static let contactDetails = LocalizedStringResource(
      "Contact Details", bundle: .atURL(Bundle.module.bundleURL))
    public static let daysUntilBirthday = LocalizedStringResource(
      "Days until birthday", bundle: .atURL(Bundle.module.bundleURL))
    public static let edit = LocalizedStringResource("Edit", bundle: .atURL(Bundle.module.bundleURL))
    public static let nextAge = LocalizedStringResource("Next age", bundle: .atURL(Bundle.module.bundleURL))
    public static let noBirthday = LocalizedStringResource(
      "No birthday recorded", bundle: .atURL(Bundle.module.bundleURL))
    public static let noNotes = LocalizedStringResource("No notes", bundle: .atURL(Bundle.module.bundleURL))
    public static let notes = LocalizedStringResource("Notes", bundle: .atURL(Bundle.module.bundleURL))
    public static let widgetPreview = LocalizedStringResource("Widget preview", bundle: .atURL(Bundle.module.bundleURL))

    public static func birthDuration(_ years: Int, _ months: Int, _ days: Int) -> String {
      let format = L10n.string(
        LocalizedStringResource("person.detail.birth.duration.format", bundle: .atURL(Bundle.module.bundleURL)))
      return String.localizedStringWithFormat(format, years, months, days)
    }

    public static func daysUntilBirthday(_ days: Int) -> String {
      let format = L10n.string(
        LocalizedStringResource("person.detail.days.until.birthday.format", bundle: .atURL(Bundle.module.bundleURL)))
      return String.localizedStringWithFormat(format, days)
    }

    public static func nextAge(_ age: Int) -> String {
      let format = L10n.string(
        LocalizedStringResource("person.detail.next.age.format", bundle: .atURL(Bundle.module.bundleURL)))
      return String.localizedStringWithFormat(format, age)
    }
  }

  public enum RelationshipGender {
    public static let female = LocalizedStringResource(
      "relationship.gender.female", bundle: .atURL(Bundle.module.bundleURL))
    public static let male = LocalizedStringResource(
      "relationship.gender.male", bundle: .atURL(Bundle.module.bundleURL))
    public static let unknown = LocalizedStringResource(
      "relationship.gender.unknown", bundle: .atURL(Bundle.module.bundleURL))
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
    public static let ageFormatDay = LocalizedStringResource(
      "widget.contact.age.format.total.days", bundle: .atURL(Bundle.module.bundleURL))
    public static let ageFormatMonthDay = LocalizedStringResource(
      "widget.contact.age.format.month.day", bundle: .atURL(Bundle.module.bundleURL))
    public static let ageFormatYearMonthDay = LocalizedStringResource(
      "widget.contact.age.format.duration", bundle: .atURL(Bundle.module.bundleURL))
    public static let choosePerson = LocalizedStringResource("Choose Person", bundle: .atURL(Bundle.module.bundleURL))
    public static let choosePersonDescription = LocalizedStringResource(
      "Choose which person's birthday this widget shows.", bundle: .atURL(Bundle.module.bundleURL))
    public static let contactAge = LocalizedStringResource("Contact Age", bundle: .atURL(Bundle.module.bundleURL))
    public static let contactAgeChoosePerson = LocalizedStringResource(
      "Choose a person to show their age.", bundle: .atURL(Bundle.module.bundleURL))
    public static let contactAgeDescription = LocalizedStringResource(
      "Track one person's current age. Tap to switch formats.", bundle: .atURL(Bundle.module.bundleURL))
    public static let contactAgeNeedsBirthYear = LocalizedStringResource(
      "Add a birth year to show age.", bundle: .atURL(Bundle.module.bundleURL))
    public static let contactAgeTapToSwitch = LocalizedStringResource(
      "Tap to switch format", bundle: .atURL(Bundle.module.bundleURL))
    public static let description = LocalizedStringResource(
      "See the next birthdays at a glance.", bundle: .atURL(Bundle.module.bundleURL))
    public static let noBirthdayRecorded = LocalizedStringResource(
      "No birthday recorded", bundle: .atURL(Bundle.module.bundleURL))
    public static let noUpcomingBirthdays = LocalizedStringResource(
      "No upcoming birthdays", bundle: .atURL(Bundle.module.bundleURL))
    public static let person = LocalizedStringResource("Person", bundle: .atURL(Bundle.module.bundleURL))
    public static let selectedPersonUnavailable = LocalizedStringResource(
      "Selected person is no longer available.", bundle: .atURL(Bundle.module.bundleURL))
    public static let title = LocalizedStringResource("Birthdays", bundle: .atURL(Bundle.module.bundleURL))
    public static let toggleAgeFormat = LocalizedStringResource(
      "Toggle Age Format", bundle: .atURL(Bundle.module.bundleURL))
    public static let upcomingBirthdays = LocalizedStringResource(
      "Upcoming Birthdays", bundle: .atURL(Bundle.module.bundleURL))

    public static func birthDuration(_ years: Int, _ months: Int, _ days: Int) -> String {
      let format = L10n.string(
        LocalizedStringResource("widget.birth.duration.format", bundle: .atURL(Bundle.module.bundleURL)))
      return String.localizedStringWithFormat(format, years, months, days)
    }

  }
}
