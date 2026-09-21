import Models
import Persistence
import SwiftUI
import WidgetKit

#Preview("year month day", as: .systemSmall) {
  ContactAgeWidget()
} timeline: {
  ContactAgeEntry(
    date: .now,
    snapshot: WidgetPersonSnapshot(
      personID: UUID(),
      displayName: "Taylor",
      nextBirthdayDate: .now.addingTimeInterval(86_400),
      age: 3,
      birthDate: .now.addingTimeInterval(-82_512_000),
      birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 3, days: 4),
      daysUntilNextBirthday: 120,
      totalBirthDays: 825,
      calendarKind: .gregorian,
      generatedAt: .now,
      sortIndex: 0),
    displayCalendarKind: .gregorian,
    stateID: nil,
    configuredDisplayFormat: .yearMonthDay,
    displayFormat: .yearMonthDay,
    selectedPersonUnavailable: false)
}

#Preview("month and day", as: .systemSmall) {
  ContactAgeWidget()
} timeline: {
  ContactAgeEntry(
    date: .now,
    snapshot: WidgetPersonSnapshot(
      personID: UUID(),
      displayName: "Taylor",
      nextBirthdayDate: .now.addingTimeInterval(86_400),
      age: 3,
      birthDate: .now.addingTimeInterval(-82_512_000),
      birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 3, days: 4),
      daysUntilNextBirthday: 120,
      totalBirthDays: 825,
      calendarKind: .gregorian,
      generatedAt: .now,
      sortIndex: 0),
    displayCalendarKind: .gregorian,
    stateID: nil,
    configuredDisplayFormat: .monthDay,
    displayFormat: .monthDay,
    selectedPersonUnavailable: false)
}

#Preview("total days", as: .systemSmall) {
  ContactAgeWidget()
} timeline: {
  ContactAgeEntry(
    date: .now,
    snapshot: WidgetPersonSnapshot(
      personID: UUID(),
      displayName: "Taylor",
      nextBirthdayDate: .now.addingTimeInterval(86_400),
      age: 3,
      birthDate: .now.addingTimeInterval(-82_512_000),
      birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 3, days: 4),
      daysUntilNextBirthday: 120,
      totalBirthDays: 825,
      calendarKind: .gregorian,
      generatedAt: .now,
      sortIndex: 0),
    displayCalendarKind: .gregorian,
    stateID: nil,
    configuredDisplayFormat: .day,
    displayFormat: .day,
    selectedPersonUnavailable: false)
}

#Preview("missing year", as: .systemSmall) {
  ContactAgeWidget()
} timeline: {
  ContactAgeEntry(
    date: .now,
    snapshot: WidgetPersonSnapshot(
      personID: UUID(),
      displayName: "Jordan",
      nextBirthdayDate: .now.addingTimeInterval(86_400),
      age: nil,
      calendarKind: .gregorian,
      generatedAt: .now,
      sortIndex: 0),
    displayCalendarKind: .gregorian,
    stateID: nil,
    configuredDisplayFormat: .yearMonthDay,
    displayFormat: .yearMonthDay,
    selectedPersonUnavailable: false)
}

#Preview("Islamic · all formats", as: .systemSmall) {
  ContactAgeWidget()
} timeline: {
  calendarPreviewEntry(calendar: .islamicUmmAlQura, format: .yearMonthDay)
  calendarPreviewEntry(calendar: .islamicUmmAlQura, format: .monthDay)
  calendarPreviewEntry(calendar: .islamicUmmAlQura, format: .day)
}

#Preview("Hebrew · long name", as: .systemSmall) {
  ContactAgeWidget()
} timeline: {
  calendarPreviewEntry(calendar: .hebrew, format: .yearMonthDay, name: "Alexandra Chen-Williams")
  calendarPreviewEntry(calendar: .hebrew, format: .monthDay, name: "欧阳小朋友的长名字")
  calendarPreviewEntry(calendar: .hebrew, format: .day, name: "欧阳小朋友的长名字")
}

private func calendarPreviewEntry(
  calendar: BirthdayCalendarKind,
  format: ContactAgeDisplayFormat,
  name: String = "Alex Chen"
) -> ContactAgeEntry {
  let date = Date(timeIntervalSince1970: 1_790_035_200)
  return ContactAgeEntry(
    date: date,
    snapshot: WidgetPersonSnapshot(
      personID: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
      displayName: name,
      nextBirthdayDate: date.addingTimeInterval(86_400),
      age: 36,
      birthDate: Date(timeIntervalSince1970: 631_152_000),
      calendarKind: .gregorian,
      generatedAt: date,
      sortIndex: 0),
    displayCalendarKind: calendar,
    stateID: "preview-calendar",
    configuredDisplayFormat: .yearMonthDay,
    displayFormat: format,
    selectedPersonUnavailable: false)
}
