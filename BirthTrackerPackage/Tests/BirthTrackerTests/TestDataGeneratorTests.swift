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
