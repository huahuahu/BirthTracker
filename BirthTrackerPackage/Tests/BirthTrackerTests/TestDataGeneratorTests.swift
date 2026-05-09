import Models
import Persistence
import SwiftData
import Testing
import TestingSupport

@Suite("Test data generation")
struct TestDataGeneratorTests {
  @Test("Sample people are inserted and saved")
  func samplePeopleAreInsertedAndSaved() async throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)

    try await TestDataGenerator.generateSamplePeople(into: context)

    let people = try context.fetch(FetchDescriptor<TrackedPerson>())
    #expect(people.count == 3)
  }
}

