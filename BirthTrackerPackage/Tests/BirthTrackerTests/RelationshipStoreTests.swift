import Foundation
import Models
import Persistence
import SwiftData
import Testing
import TestingSupport

@Suite("Relationship store")
struct RelationshipStoreTests {
  @Test("Relationship models round trip in the main SwiftData schema")
  @MainActor
  func relationshipModelsRoundTripInMainSchema() throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)
    let parentID = UUID()
    let childID = UUID()
    let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
    let fact = RelationshipFact(
      personAID: parentID,
      personBID: childID,
      kind: .parentChild,
      personARole: .parent,
      personBRole: .child,
      notes: "Father and child",
      createdAt: timestamp,
      updatedAt: timestamp)
    let preference = RelationshipDisplayPreference(
      perspectivePersonID: childID,
      targetPersonID: parentID,
      primaryFactID: fact.id,
      createdAt: timestamp,
      updatedAt: timestamp)

    context.insert(fact)
    context.insert(preference)
    try context.save()

    let verificationContext = ModelContext(container)
    let facts = try verificationContext.fetch(FetchDescriptor<RelationshipFact>())
    let preferences = try verificationContext.fetch(FetchDescriptor<RelationshipDisplayPreference>())

    let fetchedFact = try #require(facts.first)
    #expect(fetchedFact.personAID == parentID)
    #expect(fetchedFact.personBID == childID)
    #expect(fetchedFact.kind == .parentChild)
    #expect(fetchedFact.personARole == .parent)
    #expect(fetchedFact.personBRole == .child)
    #expect(fetchedFact.notes == "Father and child")
    #expect(fetchedFact.createdAt == timestamp)
    #expect(fetchedFact.updatedAt == timestamp)

    let fetchedPreference = try #require(preferences.first)
    #expect(fetchedPreference.perspectivePersonID == childID)
    #expect(fetchedPreference.targetPersonID == parentID)
    #expect(fetchedPreference.primaryFactID == fact.id)
    #expect(fetchedPreference.createdAt == timestamp)
    #expect(fetchedPreference.updatedAt == timestamp)
  }
}
