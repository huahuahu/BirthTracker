import Models
import SwiftUI
import WidgetKit

#Preview("small", as: .systemSmall) {
  UpcomingBirthdaysWidget()
} timeline: {
  UpcomingBirthdaysEntry(
    date: .now,
    birthdays: [
      UpcomingBirthday(
        id: UUID(),
        personName: "Taylor",
        date: .now,
        age: 30,
        calendarKind: .gregorian,
        birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 0, days: 0),
        daysUntilNextBirthday: 30),
      UpcomingBirthday(
        id: UUID(),
        personName: "Jordan",
        date: .now.addingTimeInterval(172_800),
        age: 28,
        calendarKind: .gregorian,
        birthDuration: PersonBirthdaySummary.BirthDuration(years: 1, months: 3, days: 4),
        daysUntilNextBirthday: 32),
      UpcomingBirthday(
        id: UUID(),
        personName: "Morgan",
        date: .now.addingTimeInterval(259_200),
        age: 34,
        calendarKind: .gregorian,
        birthDuration: PersonBirthdaySummary.BirthDuration(years: 0, months: 8, days: 12),
        daysUntilNextBirthday: 30),
    ],
    selectedPersonUnavailable: false)
}

#Preview("medium", as: .systemMedium) {
  UpcomingBirthdaysWidget()
} timeline: {
  UpcomingBirthdaysEntry(
    date: .now,
    birthdays: [
      UpcomingBirthday(
        id: UUID(),
        personName: "Taylor",
        date: .now,
        age: 30,
        calendarKind: .gregorian,
        birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 0, days: 0),
        daysUntilNextBirthday: 30)
    ],
    selectedPersonUnavailable: false)
}
