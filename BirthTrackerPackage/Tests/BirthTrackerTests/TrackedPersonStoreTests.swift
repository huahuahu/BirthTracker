import Foundation
import Models
import Persistence
import SwiftData
import Testing
import TestingSupport

@Suite("Tracked person store")
struct TrackedPersonStoreTests {
  @Test("Deleting a tracked person removes relationship facts that reference it")
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
    _ = try relationshipStore.setPrimaryDisplayFact(
      perspectivePersonID: removedPerson.id,
      targetPersonID: keptPerson.id,
      primaryFactID: removedFact.id)
    _ = try relationshipStore.setPrimaryDisplayFact(
      perspectivePersonID: keptPerson.id,
      targetPersonID: unrelatedPerson.id,
      primaryFactID: keptFact.id)

    try TrackedPersonStore(context: context).delete(removedPerson)

    let people = try context.fetch(FetchDescriptor<TrackedPerson>())
    let facts = try context.fetch(FetchDescriptor<RelationshipFact>())
    #expect(people.map(\.id).contains(removedPerson.id) == false)
    #expect(people.map(\.id).contains(keptPerson.id))
    #expect(facts.count == 1)
    #expect(facts.first?.id == keptFact.id)
    #expect(facts.first?.isPrimary(from: keptPerson.id) == true)
  }
}
