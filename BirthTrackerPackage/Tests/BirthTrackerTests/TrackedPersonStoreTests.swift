import Foundation
import Models
import Persistence
import SwiftData
import Testing
import TestingSupport

@Suite("Tracked person store")
struct TrackedPersonStoreTests {
  @Test("Deleting a tracked person removes relationship facts and preferences that reference it")
  @MainActor
  func deletingTrackedPersonRemovesRelationshipReferences() throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)
    let removedPerson = TrackedPerson(
      id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
      name: "Removed Person",
      birthday: Birthday(calendarKind: .gregorian, year: 1990, month: 1, day: 1))
    let keptPerson = TrackedPerson(
      id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002")),
      name: "Kept Person",
      birthday: Birthday(calendarKind: .gregorian, year: 1991, month: 2, day: 2))
    let unrelatedPerson = TrackedPerson(
      id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000003")),
      name: "Unrelated Person",
      birthday: Birthday(calendarKind: .gregorian, year: 1992, month: 3, day: 3))
    context.insert(removedPerson)
    context.insert(keptPerson)
    context.insert(unrelatedPerson)
    try context.save()

    let relationshipStore = RelationshipStore(context: context, now: { Date(timeIntervalSince1970: 1_800_000_000) })
    let removedFact = try relationshipStore.createFact(
      personAID: removedPerson.id,
      personBID: keptPerson.id,
      kind: .friend,
      personARole: .friend,
      personBRole: .friend)
    let keptFact = try relationshipStore.createFact(
      personAID: keptPerson.id,
      personBID: unrelatedPerson.id,
      kind: .coworker,
      personARole: .coworker,
      personBRole: .coworker)
    _ = try relationshipStore.setDisplayPreference(
      perspectivePersonID: removedPerson.id,
      targetPersonID: keptPerson.id,
      primaryFactID: removedFact.id)
    _ = try relationshipStore.setDisplayPreference(
      perspectivePersonID: keptPerson.id,
      targetPersonID: unrelatedPerson.id,
      primaryFactID: keptFact.id)

    try TrackedPersonStore(context: context).delete(removedPerson)

    let people = try context.fetch(FetchDescriptor<TrackedPerson>())
    let facts = try context.fetch(FetchDescriptor<RelationshipFact>())
    let preferences = try context.fetch(FetchDescriptor<RelationshipDisplayPreference>())
    #expect(people.map(\.id).contains(removedPerson.id) == false)
    #expect(people.map(\.id).contains(keptPerson.id))
    #expect(facts.count == 1)
    #expect(facts.first?.id == keptFact.id)
    #expect(preferences.count == 1)
    #expect(preferences.first?.perspectivePersonID == keptPerson.id)
    #expect(preferences.first?.targetPersonID == unrelatedPerson.id)
  }

  @Test("Deleting a tracked person removes legacy preferences pointing at deleted relationship facts")
  @MainActor
  func deletingTrackedPersonRemovesLegacyPreferencesPointingAtDeletedFacts() throws {
    let container = try PersistenceFixtures.makeInMemoryContainer()
    let context = ModelContext(container)
    let removedPerson = TrackedPerson(
      id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
      name: "Removed Person",
      birthday: Birthday(calendarKind: .gregorian, year: 1990, month: 1, day: 1))
    let factPeer = TrackedPerson(
      id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002")),
      name: "Fact Peer",
      birthday: Birthday(calendarKind: .gregorian, year: 1991, month: 2, day: 2))
    let perspectivePerson = TrackedPerson(
      id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000003")),
      name: "Perspective Person",
      birthday: Birthday(calendarKind: .gregorian, year: 1992, month: 3, day: 3))
    let targetPerson = TrackedPerson(
      id: try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000004")),
      name: "Target Person",
      birthday: Birthday(calendarKind: .gregorian, year: 1993, month: 4, day: 4))
    let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
    let deletedFact = RelationshipFact(
      personAID: removedPerson.id,
      personBID: factPeer.id,
      kind: .friend,
      personARole: .friend,
      personBRole: .friend,
      createdAt: timestamp,
      updatedAt: timestamp)
    let legacyInvalidPreference = RelationshipDisplayPreference(
      perspectivePersonID: perspectivePerson.id,
      targetPersonID: targetPerson.id,
      primaryFactID: deletedFact.id,
      createdAt: timestamp,
      updatedAt: timestamp)
    context.insert(removedPerson)
    context.insert(factPeer)
    context.insert(perspectivePerson)
    context.insert(targetPerson)
    context.insert(deletedFact)
    context.insert(legacyInvalidPreference)
    try context.save()

    try TrackedPersonStore(context: context).delete(removedPerson)

    let facts = try context.fetch(FetchDescriptor<RelationshipFact>())
    let preferences = try context.fetch(FetchDescriptor<RelationshipDisplayPreference>())
    #expect(facts.isEmpty)
    #expect(preferences.isEmpty)
  }
}
