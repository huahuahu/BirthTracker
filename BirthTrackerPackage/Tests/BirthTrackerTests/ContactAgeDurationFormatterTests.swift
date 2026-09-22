import Foundation
import Models
import Testing

@testable import BirthTrackerWidgets

@Suite("Contact age duration formatter")
struct ContactAgeDurationFormatterTests {
  @Test(
    "Display formats calculate directly from dates in the selected calendar",
    arguments: [
      (BirthdayCalendarKind.gregorian, ContactAgeDisplayFormat.yearMonthDay, "1 year, 4 months, 6 days"),
      (.gregorian, .monthDay, "16 months, 6 days"),
      (.gregorian, .day, "494 days"),
      (.chinese, .yearMonthDay, "1 year, 3 months, 22 days"),
      (.chinese, .monthDay, "16 months, 22 days"),
      (.chinese, .day, "494 days"),
    ])
  func displayFormatsUseDates(kind: BirthdayCalendarKind, format: ContactAgeDisplayFormat, expected: String) throws {
    let birthDate = try date(2025, 5, 16)
    let referenceDate = try date(2026, 9, 22)
    #expect(
      ContactAgeDurationFormatter().string(
        from: birthDate,
        to: referenceDate,
        calendarKind: kind,
        displayFormat: format,
        locale: Locale(identifier: "en_US")) == expected)
  }

  @Test(
    "Total months count leap months across complete years",
    arguments: [
      (BirthdayCalendarKind.chinese, (2025, 1, 29), (2026, 2, 17), "13 months"),
      (.chinese, (2023, 1, 22), (2026, 2, 17), "38 months"),
      (.chinese, (2024, 2, 10), (2025, 1, 29), "12 months"),
      (.hebrew, (2023, 9, 16), (2024, 10, 3), "13 months"),
      (.gregorian, (1990, 1, 12), (2026, 8, 30), "439 months, 18 days"),
      (.islamicUmmAlQura, (1990, 1, 12), (2026, 8, 30), "453 months, 3 days"),
    ])
  func totalMonthsIncludeLeapMonths(
    kind: BirthdayCalendarKind,
    birth: (Int, Int, Int),
    end: (Int, Int, Int),
    expected: String
  ) throws {
    let birthDate = try date(birth.0, birth.1, birth.2)
    let referenceDate = try date(end.0, end.1, end.2)
    #expect(
      ContactAgeDurationFormatter().string(
        from: birthDate,
        to: referenceDate,
        calendarKind: kind,
        displayFormat: .monthDay,
        locale: Locale(identifier: "en_US")) == expected)
  }

  @Test("Future birth dates clamp to zero", arguments: [ContactAgeDisplayFormat.yearMonthDay, .monthDay, .day])
  func futureBirthDateClampsToZero(format: ContactAgeDisplayFormat) throws {
    let birthDate = try date(2027, 1, 1)
    let referenceDate = try date(2026, 9, 22)
    #expect(
      ContactAgeDurationFormatter().string(
        from: birthDate,
        to: referenceDate,
        calendarKind: .chinese,
        displayFormat: format,
        locale: Locale(identifier: "en_US")) == "0 days")
  }

  @Test("Duration ignores time of day and uses complete civil days")
  func durationIgnoresTimeOfDay() throws {
    let calendar = BirthdayCalendarKind.gregorian.calendar
    let birthDate = try #require(calendar.date(from: DateComponents(year: 2024, month: 7, day: 5, hour: 23)))
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 1)))
    #expect(
      ContactAgeDurationFormatter().string(
        from: birthDate,
        to: referenceDate,
        calendarKind: .gregorian,
        displayFormat: .monthDay,
        locale: Locale(identifier: "en_US")) == "24 months")
    #expect(
      ContactAgeDurationFormatter().string(
        from: birthDate,
        to: referenceDate,
        calendarKind: .gregorian,
        displayFormat: .day,
        locale: Locale(identifier: "en_US")) == "730 days")
  }

  private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
    try #require(
      BirthdayCalendarKind.gregorian.calendar.date(
        from: DateComponents(year: year, month: month, day: day, hour: 12)))
  }

  @Test("Since birth uses the widget localization catalog")
  func sinceBirthUsesWidgetLocalizationCatalog() {
    #expect(
      WidgetL10n.contactAgeSinceBirth(locale: Locale(identifier: "en")) == "Since birth")
  }

  @Test(
    "Calendar captions name the resolved calendar without configuration wording",
    arguments: [
      (BirthdayCalendarKind.gregorian, "Gregorian"),
      (.chinese, "Chinese"),
      (.buddhist, "Buddhist"),
      (.hebrew, "Hebrew"),
      (.islamicUmmAlQura, "Islamic"),
    ])
  func resolvedCalendarCaption(calendar: BirthdayCalendarKind, expected: String) {
    #expect(WidgetL10n.calendarName(calendar, locale: Locale(identifier: "en")) == expected)
  }
}
