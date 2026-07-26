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
    displayFormat: .yearMonthDay,
    selectedPersonUnavailable: false)
}
