import Models
import Persistence
import SwiftData
import Testing
import TestingSupport

@Suite("Test data generation")
struct TestDataGeneratorTests {
  @Test("Sample people are inserted and saved")
  @MainActor
  func samplePeopleAreInsertedAndSaved() async throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)

    try await TestDataGenerator.generateSamplePeople(into: context)

    let people = try context.fetch(FetchDescriptor<TrackedPerson>())
    #expect(people.count == 3)
  }

  @Test("Reset deletes existing people before inserting samples")
  @MainActor
  func resetDeletesExistingPeopleBeforeInsertingSamples() async throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)
    context.insert(
      TrackedPerson(
        name: "Existing Person",
        birthday: Birthday(calendarKind: .gregorian, year: 2001, month: 2, day: 3),
        notes: "Should be removed by reset"
      ))
    try context.save()

    try await TestDataGenerator.resetSamplePeople(into: context)

    let people = try context.fetch(FetchDescriptor<TrackedPerson>())
    #expect(people.count == 3)
    #expect(!people.contains { $0.name == "Existing Person" })
    #expect(people.contains { $0.name == "Alex Chen" })
    #expect(people.contains { $0.name == "Jamie Lin" })
    #expect(people.contains { $0.name == "Morgan Lee" })
  }

  @Test("Cancellation leaves the context unchanged")
  @MainActor
  func cancellationLeavesContextUnchanged() async throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)

    let generationTask = Task { @MainActor in
      try await TestDataGenerator.generateSamplePeople(into: context)
    }

    await Task.yield()
    generationTask.cancel()

    do {
      try await generationTask.value
      Issue.record("Expected sample data generation to be cancelled")
    } catch is CancellationError {
    }

    let people = try context.fetch(FetchDescriptor<TrackedPerson>())
    #expect(people.isEmpty)
  }
}
