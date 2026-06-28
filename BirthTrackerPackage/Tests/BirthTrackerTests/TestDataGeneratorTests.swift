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

    let verificationContext = ModelContext(container)
    let people = try verificationContext.fetch(FetchDescriptor<TrackedPerson>())
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

    let verificationContext = ModelContext(container)
    let people = try verificationContext.fetch(FetchDescriptor<TrackedPerson>())
    #expect(people.count == 3)
    #expect(!people.contains { $0.name == "Existing Person" })
    #expect(people.contains { $0.name == "Alex Chen" })
    #expect(people.contains { $0.name == "Jamie Lin" })
    #expect(people.contains { $0.name == "Morgan Lee" })
  }

  @Test("Reset does not save unrelated pending inserts in the caller context")
  @MainActor
  func resetDoesNotSaveUnrelatedPendingInsertsInCallerContext() async throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let callerContext = ModelContext(container)
    let draftPerson = TrackedPerson(
      name: "Unsaved Draft",
      birthday: Birthday(calendarKind: .gregorian, year: 2002, month: 4, day: 6),
      notes: "Should stay pending in caller context"
    )
    callerContext.insert(draftPerson)

    #expect(callerContext.hasChanges)

    try await TestDataGenerator.resetSamplePeople(into: callerContext)

    #expect(callerContext.hasChanges)
    let callerPeople = try callerContext.fetch(FetchDescriptor<TrackedPerson>())
    #expect(callerPeople.contains { $0.name == "Unsaved Draft" })

    let verificationContext = ModelContext(container)
    let persistedPeople = try verificationContext.fetch(FetchDescriptor<TrackedPerson>())
    #expect(persistedPeople.count == 3)
    #expect(!persistedPeople.contains { $0.name == "Unsaved Draft" })
    #expect(persistedPeople.contains { $0.name == "Alex Chen" })
    #expect(persistedPeople.contains { $0.name == "Jamie Lin" })
    #expect(persistedPeople.contains { $0.name == "Morgan Lee" })
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
