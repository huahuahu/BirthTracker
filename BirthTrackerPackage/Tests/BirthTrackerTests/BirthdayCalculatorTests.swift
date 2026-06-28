import Foundation
import Models
import Persistence
import SwiftData
import Testing
import TestingSupport

@Suite("Birthday calculation")
struct BirthdayCalculatorTests {
  @Test("Next occurrence stays in the current year when still upcoming")
  func nextOccurrenceInCurrentYear() throws {
    let calendar = Calendar(identifier: .gregorian)
    let reference = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 5, hour: 12)))
    let birthday = Birthday(calendarKind: .gregorian, year: 1990, month: 6, day: 10)

    let next = try #require(BirthdayCalculator.nextOccurrence(for: birthday, after: reference))
    let components = calendar.dateComponents([.year, .month, .day], from: next)

    #expect(components.year == 2026)
    #expect(components.month == 6)
    #expect(components.day == 10)
    #expect(BirthdayCalculator.age(on: next, for: birthday) == 36)
  }

  @Test("Next occurrence includes birthdays happening today")
  func nextOccurrenceIncludesToday() throws {
    let calendar = Calendar(identifier: .gregorian)
    let reference = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 5, hour: 19)))
    let birthday = Birthday(calendarKind: .gregorian, year: 2026, month: 5, day: 5)

    let next = try #require(BirthdayCalculator.nextOccurrence(for: birthday, after: reference))
    let components = calendar.dateComponents([.year, .month, .day], from: next)

    #expect(components.year == 2026)
    #expect(components.month == 5)
    #expect(components.day == 5)
    #expect(BirthdayCalculator.age(on: next, for: birthday) == 0)
  }

  @Test("Next occurrence rolls to the next year once passed")
  func nextOccurrenceRollsForward() throws {
    let calendar = Calendar(identifier: .gregorian)
    let reference = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 12)))
    let birthday = Birthday(calendarKind: .gregorian, year: 1990, month: 6, day: 10)

    let next = try #require(BirthdayCalculator.nextOccurrence(for: birthday, after: reference))
    let components = calendar.dateComponents([.year, .month, .day], from: next)

    #expect(components.year == 2027)
    #expect(components.month == 6)
    #expect(components.day == 10)
  }

  @Test("In-memory persistence stores template fixture data")
  func inMemoryPersistenceStoresFixtureData() throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)

    for person in PersistenceFixtures.makePeople() {
      context.insert(person)
    }

    try context.save()

    let people = try context.fetch(FetchDescriptor<TrackedPerson>())
    #expect(people.count == 3)
  }
}
