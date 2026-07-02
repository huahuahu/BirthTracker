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

  @Test("Store creates facts with normalized endpoints and service timestamps")
  @MainActor
  func storeCreatesFactsWithNormalizedEndpointsAndServiceTimestamps() throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)
    let earlyID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
    let lateID = try #require(UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"))
    let timestamp = Date(timeIntervalSince1970: 1_800_000_100)
    let store = RelationshipStore(context: context, now: { timestamp })

    let fact = try store.createFact(
      personAID: lateID,
      personBID: earlyID,
      kind: .parentChild,
      personARole: .parent,
      personBRole: .child,
      notes: "Created through store")

    #expect(fact.personAID == earlyID)
    #expect(fact.personBID == lateID)
    #expect(fact.personARole == .child)
    #expect(fact.personBRole == .parent)
    #expect(fact.createdAt == timestamp)
    #expect(fact.updatedAt == timestamp)
  }

  @Test("Store updates notes and advances updatedAt without changing createdAt")
  @MainActor
  func storeUpdatesNotesAndAdvancesUpdatedAt() throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)
    let firstTimestamp = Date(timeIntervalSince1970: 1_800_000_000)
    let secondTimestamp = Date(timeIntervalSince1970: 1_800_000_500)
    var timestamps = [firstTimestamp, secondTimestamp]
    let store = RelationshipStore(context: context, now: { timestamps.removeFirst() })
    let fact = try store.createFact(
      personAID: UUID(),
      personBID: UUID(),
      kind: .classmate,
      personARole: .classmate,
      personBRole: .classmate)

    let updatedFact = try store.updateNotes(factID: fact.id, notes: "Updated")

    #expect(updatedFact.notes == "Updated")
    #expect(updatedFact.createdAt == firstTimestamp)
    #expect(updatedFact.updatedAt == secondTimestamp)
  }

  @Test("Store rejects duplicate relationship facts even when endpoints are reversed")
  @MainActor
  func storeRejectsDuplicateFactsWithReversedEndpoints() throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)
    let personAID = UUID()
    let personBID = UUID()
    let store = RelationshipStore(context: context, now: { Date(timeIntervalSince1970: 1_800_000_000) })

    _ = try store.createFact(
      personAID: personAID,
      personBID: personBID,
      kind: .sibling,
      personARole: .sibling,
      personBRole: .sibling)

    #expect(throws: RelationshipStoreError.duplicateFact) {
      _ = try store.createFact(
        personAID: personBID,
        personBID: personAID,
        kind: .sibling,
        personARole: .sibling,
        personBRole: .sibling)
    }
  }

  @Test("Display preferences are directional and update timestamps through the store")
  @MainActor
  func displayPreferencesAreDirectionalAndTimestamped() throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)
    let firstTimestamp = Date(timeIntervalSince1970: 1_800_000_000)
    let secondTimestamp = Date(timeIntervalSince1970: 1_800_000_500)
    let thirdTimestamp = Date(timeIntervalSince1970: 1_800_001_000)
    var timestamps = [firstTimestamp, secondTimestamp, thirdTimestamp]
    let store = RelationshipStore(context: context, now: { timestamps.removeFirst() })
    let personAID = UUID()
    let personBID = UUID()
    let firstFactID = UUID()
    let secondFactID = UUID()

    let firstPreference = try store.setDisplayPreference(
      perspectivePersonID: personAID,
      targetPersonID: personBID,
      primaryFactID: firstFactID)
    let reversePreference = try store.setDisplayPreference(
      perspectivePersonID: personBID,
      targetPersonID: personAID,
      primaryFactID: secondFactID)
    let updatedPreference = try store.setDisplayPreference(
      perspectivePersonID: personAID,
      targetPersonID: personBID,
      primaryFactID: secondFactID)

    #expect(firstPreference.id == updatedPreference.id)
    #expect(updatedPreference.primaryFactID == secondFactID)
    #expect(updatedPreference.createdAt == firstTimestamp)
    #expect(updatedPreference.updatedAt == thirdTimestamp)
    #expect(reversePreference.perspectivePersonID == personBID)
    #expect(reversePreference.targetPersonID == personAID)
    #expect(reversePreference.primaryFactID == secondFactID)
    #expect(reversePreference.createdAt == secondTimestamp)
    #expect(reversePreference.updatedAt == secondTimestamp)
  }

  @Test("Deleting person references removes facts and preferences")
  @MainActor
  func deletingPersonReferencesRemovesFactsAndPreferences() throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)
    let store = RelationshipStore(context: context, now: { Date(timeIntervalSince1970: 1_800_000_000) })
    let removedPersonID = UUID()
    let keptPersonID = UUID()
    let unrelatedPersonID = UUID()
    _ = try store.createFact(
      personAID: removedPersonID,
      personBID: keptPersonID,
      kind: .friend,
      personARole: .friend,
      personBRole: .friend)
    let keptFact = try store.createFact(
      personAID: keptPersonID,
      personBID: unrelatedPersonID,
      kind: .coworker,
      personARole: .coworker,
      personBRole: .coworker)
    _ = try store.setDisplayPreference(
      perspectivePersonID: removedPersonID,
      targetPersonID: keptPersonID,
      primaryFactID: keptFact.id)
    _ = try store.setDisplayPreference(
      perspectivePersonID: keptPersonID,
      targetPersonID: unrelatedPersonID,
      primaryFactID: keptFact.id)

    try store.deleteReferences(toPersonID: removedPersonID)

    let facts = try context.fetch(FetchDescriptor<RelationshipFact>())
    let preferences = try context.fetch(FetchDescriptor<RelationshipDisplayPreference>())
    #expect(facts.count == 1)
    #expect(facts.first?.id == keptFact.id)
    #expect(preferences.count == 1)
    #expect(preferences.first?.perspectivePersonID == keptPersonID)
    #expect(preferences.first?.targetPersonID == unrelatedPersonID)
  }

}
