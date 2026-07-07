import Foundation
import Models
import Testing

@Suite("Person birthday summary")
struct PersonBirthdaySummaryTests {
  @Test("Summary includes duration and next birthday for full birth date")
  func summaryIncludesDurationAndNextBirthdayForFullBirthDate() throws {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 10)))
    let person = TrackedPerson(
      name: "An An",
      birthday: Birthday(calendarKind: .gregorian, year: 2024, month: 7, day: 5))

    let summary = PersonBirthdaySummary.make(for: person, referenceDate: referenceDate)

    #expect(summary.personName == "An An")
    #expect(summary.calendarKind == .gregorian)
    #expect(summary.birthDuration == PersonBirthdaySummary.BirthDuration(years: 2, months: 0, days: 0))
    #expect(summary.daysUntilNextBirthday == 0)
    #expect(summary.totalBirthDays == 730)
    #expect(summary.nextAge == 2)
    #expect(summary.nextBirthdayDate != nil)
  }

  @Test("Summary calculates days until the next birthday")
  func summaryCalculatesDaysUntilTheNextBirthday() throws {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 10)))
    let person = TrackedPerson(
      name: "Future Birthday",
      birthday: Birthday(calendarKind: .gregorian, year: 2024, month: 7, day: 5))

    let summary = PersonBirthdaySummary.make(for: person, referenceDate: referenceDate)

    #expect(summary.birthDuration == PersonBirthdaySummary.BirthDuration(years: 1, months: 9, days: 26))
    #expect(summary.daysUntilNextBirthday == 65)
    #expect(summary.totalBirthDays == 665)
    #expect(summary.nextAge == 2)
  }

  @Test("Summary omits age dependent values when birth year is unknown")
  func summaryOmitsAgeDependentValuesWhenBirthYearIsUnknown() throws {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 10)))
    let person = TrackedPerson(
      name: "Unknown Year",
      birthday: Birthday(calendarKind: .gregorian, year: nil, month: 7, day: 5))

    let summary = PersonBirthdaySummary.make(for: person, referenceDate: referenceDate)

    #expect(summary.birthDate == nil)
    #expect(summary.birthDuration == nil)
    #expect(summary.totalBirthDays == nil)
    #expect(summary.nextAge == nil)
    #expect(summary.daysUntilNextBirthday == 65)
    #expect(summary.nextBirthdayDate != nil)
  }

  @Test("Summary handles people without birthdays")
  func summaryHandlesPeopleWithoutBirthdays() {
    let person = TrackedPerson(name: "No Birthday")

    let summary = PersonBirthdaySummary.make(for: person)

    #expect(summary.personName == "No Birthday")
    #expect(summary.birthDate == nil)
    #expect(summary.birthDuration == nil)
    #expect(summary.totalBirthDays == nil)
    #expect(summary.nextBirthdayDate == nil)
    #expect(summary.daysUntilNextBirthday == nil)
    #expect(summary.nextAge == nil)
  }

  @Test("Summary clamps total birth days for future birth dates")
  func summaryClampsTotalBirthDaysForFutureBirthDates() throws {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 10)))
    let person = TrackedPerson(
      name: "Future Birth",
      birthday: Birthday(calendarKind: .gregorian, year: 2027, month: 1, day: 1))

    let summary = PersonBirthdaySummary.make(for: person, referenceDate: referenceDate)

    #expect(summary.birthDuration == PersonBirthdaySummary.BirthDuration(years: 0, months: 0, days: 0))
    #expect(summary.totalBirthDays == 0)
  }
}
