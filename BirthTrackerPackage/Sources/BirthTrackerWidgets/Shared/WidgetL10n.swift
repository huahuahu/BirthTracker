import Foundation

enum WidgetL10n {
  static let ageFormatDay = LocalizedStringResource(
    "widget.contact.age.format.total.days",
    bundle: .atURL(Bundle.module.bundleURL))
  static let ageFormatMonthDay = LocalizedStringResource(
    "widget.contact.age.format.month.day",
    bundle: .atURL(Bundle.module.bundleURL))
  static let ageFormatYearMonthDay = LocalizedStringResource(
    "widget.contact.age.format.duration",
    bundle: .atURL(Bundle.module.bundleURL))
  static let contactAge = LocalizedStringResource(
    "Contact Age",
    bundle: .atURL(Bundle.module.bundleURL))
  static let contactAgeChoosePerson = LocalizedStringResource(
    "Choose a person to show their age.",
    bundle: .atURL(Bundle.module.bundleURL))
  static let contactAgeDescription = LocalizedStringResource(
    "Track one person's current age. Tap to switch formats.",
    bundle: .atURL(Bundle.module.bundleURL))
  static let contactAgeNeedsBirthYear = LocalizedStringResource(
    "Add a birth year to show age.",
    bundle: .atURL(Bundle.module.bundleURL))
  static let contactAgeTapToSwitch = LocalizedStringResource(
    "Tap to switch format",
    bundle: .atURL(Bundle.module.bundleURL))
  static let description = LocalizedStringResource(
    "See the next birthdays at a glance.",
    bundle: .atURL(Bundle.module.bundleURL))
  static let noBirthdayRecorded = LocalizedStringResource(
    "No birthday recorded",
    bundle: .atURL(Bundle.module.bundleURL))
  static let noUpcomingBirthdays = LocalizedStringResource(
    "No upcoming birthdays",
    bundle: .atURL(Bundle.module.bundleURL))
  static let selectedPersonUnavailable = LocalizedStringResource(
    "Selected person is no longer available.",
    bundle: .atURL(Bundle.module.bundleURL))
  static let title = LocalizedStringResource(
    "Birthdays",
    bundle: .atURL(Bundle.module.bundleURL))
  static let upcomingBirthdays = LocalizedStringResource(
    "Upcoming Birthdays",
    bundle: .atURL(Bundle.module.bundleURL))

  static func string(_ resource: LocalizedStringResource) -> String {
    String(localized: resource)
  }

  static func birthDuration(_ years: Int, _ months: Int, _ days: Int) -> String {
    let format = string(
      LocalizedStringResource(
        "widget.birth.duration.format",
        bundle: .atURL(Bundle.module.bundleURL)))
    return String.localizedStringWithFormat(format, years, months, days)
  }

  static func daysUntilBirthday(_ days: Int) -> String {
    let format = string(
      LocalizedStringResource(
        "person.detail.days.until.birthday.format",
        bundle: .atURL(Bundle.module.bundleURL)))
    return String.localizedStringWithFormat(format, days)
  }
}
