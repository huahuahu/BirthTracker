import Models
import SwiftData

@MainActor
public struct TrackedPersonStore {
  private let context: ModelContext

  public init(context: ModelContext) {
    self.context = context
  }

  public func delete(_ person: TrackedPerson) throws {
    try delete([person])
  }

  public func delete(_ people: [TrackedPerson]) throws {
    try stageDelete(people)
    try context.save()
  }

  public func deleteAllTrackedPeople() throws {
    try stageDeleteAllTrackedPeople()
    try context.save()
  }

  func stageDeleteAllTrackedPeople() throws {
    let people = try context.fetch(FetchDescriptor<TrackedPerson>())
    try stageDelete(people)
  }

  private func stageDelete(_ people: [TrackedPerson]) throws {
    let relationshipStore = RelationshipStore(context: context)

    for person in people {
      try relationshipStore.deleteReferences(toPersonID: person.id, save: false)
      context.delete(person)
    }
  }
}
