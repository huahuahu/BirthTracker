import Foundation
import Models
import Persistence
import SwiftData
import Testing
import TestingSupport

@Suite("Tracked person model")
struct TrackedPersonModelTests {
  @Test("Birthday relationship round trips in the main SwiftData schema")
  @MainActor
  func birthdayRelationshipRoundTripsInMainSchema() throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)
    let birthday = Birthday(calendarKind: .gregorian, era: 1, year: 1990, month: 6, day: 10)
    let person = TrackedPerson(name: "Birthday Person", birthday: birthday)

    context.insert(person)
    try context.save()

    let verificationContext = ModelContext(container)
    let people = try verificationContext.fetch(FetchDescriptor<TrackedPerson>())
    let birthdays = try verificationContext.fetch(FetchDescriptor<Birthday>())
    let fetchedPerson = try #require(people.first)
    let fetchedBirthday = try #require(birthdays.first)
    #expect(fetchedPerson.birthday?.day == 10)
    #expect(fetchedBirthday.person?.id == fetchedPerson.id)
  }

  @Test("Deleting a tracked person cascades to its birthday")
  @MainActor
  func deletingTrackedPersonCascadesToItsBirthday() throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)
    let person = TrackedPerson(
      name: "Birthday Person",
      birthday: Birthday(calendarKind: .gregorian, year: 1990, month: 6, day: 10))
    context.insert(person)
    try context.save()

    context.delete(person)
    try context.save()

    let verificationContext = ModelContext(container)
    #expect(try verificationContext.fetch(FetchDescriptor<TrackedPerson>()).isEmpty)
    #expect(try verificationContext.fetch(FetchDescriptor<Birthday>()).isEmpty)
  }

  @Test("Deleting a birthday clears the person birthday without deleting the person")
  @MainActor
  func deletingBirthdayClearsPersonBirthdayWithoutDeletingPerson() throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)
    let person = TrackedPerson(
      name: "Birthday Person",
      birthday: Birthday(calendarKind: .gregorian, year: 1990, month: 6, day: 10))
    context.insert(person)
    try context.save()
    let birthday = try #require(person.birthday)

    context.delete(birthday)
    try context.save()

    let verificationContext = ModelContext(container)
    let people = try verificationContext.fetch(FetchDescriptor<TrackedPerson>())
    let fetchedPerson = try #require(people.first)
    #expect(people.count == 1)
    #expect(fetchedPerson.birthday == nil)
    #expect(try verificationContext.fetch(FetchDescriptor<Birthday>()).isEmpty)
  }
}
