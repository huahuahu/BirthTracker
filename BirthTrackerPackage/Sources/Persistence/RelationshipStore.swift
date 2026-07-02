import Foundation
import Models
import SwiftData

public enum RelationshipStoreError: Error, Equatable {
  case duplicateFact
  case factNotFound(UUID)
  case invalidSelfRelationship(UUID)
}

@MainActor
public struct RelationshipStore {
  private struct NormalizedEndpointPair {
    let personAID: UUID
    let personBID: UUID
    let personARole: RelationshipRole
    let personBRole: RelationshipRole
  }

  private let context: ModelContext
  private let now: () -> Date

  public init(context: ModelContext, now: @escaping () -> Date = { Date() }) {
    self.context = context
    self.now = now
  }

  @discardableResult
  public func createFact(
    personAID: UUID,
    personBID: UUID,
    kind: RelationshipKind,
    personARole: RelationshipRole,
    personBRole: RelationshipRole,
    notes: String = ""
  ) throws -> RelationshipFact {
    let normalized = try normalizedEndpointPair(
      personAID: personAID,
      personBID: personBID,
      personARole: personARole,
      personBRole: personBRole
    )

    if try fetchMatchingFact(
      personAID: normalized.personAID,
      personBID: normalized.personBID,
      kind: kind,
      personARole: normalized.personARole,
      personBRole: normalized.personBRole
    ) != nil {
      throw RelationshipStoreError.duplicateFact
    }

    let timestamp = now()
    let fact = RelationshipFact(
      personAID: normalized.personAID,
      personBID: normalized.personBID,
      kind: kind,
      personARole: normalized.personARole,
      personBRole: normalized.personBRole,
      notes: notes,
      createdAt: timestamp,
      updatedAt: timestamp
    )
    context.insert(fact)
    try context.save()
    return fact
  }

  @discardableResult
  public func updateFact(
    id: UUID,
    kind: RelationshipKind,
    personARole: RelationshipRole,
    personBRole: RelationshipRole,
    notes: String
  ) throws -> RelationshipFact {
    let fact = try fetchFact(id: id)
    let normalized = try normalizedEndpointPair(
      personAID: fact.personAID,
      personBID: fact.personBID,
      personARole: personARole,
      personBRole: personBRole
    )

    let duplicate = try fetchMatchingFact(
      personAID: normalized.personAID,
      personBID: normalized.personBID,
      kind: kind,
      personARole: normalized.personARole,
      personBRole: normalized.personBRole
    )
    if let duplicate, duplicate.id != id {
      throw RelationshipStoreError.duplicateFact
    }

    fact.personAID = normalized.personAID
    fact.personBID = normalized.personBID
    fact.kind = kind
    fact.personARole = normalized.personARole
    fact.personBRole = normalized.personBRole
    fact.notes = notes
    fact.updatedAt = now()
    try context.save()
    return fact
  }

  @discardableResult
  public func updateNotes(factID: UUID, notes: String) throws -> RelationshipFact {
    let fact = try fetchFact(id: factID)
    fact.notes = notes
    fact.updatedAt = now()
    try context.save()
    return fact
  }

  @discardableResult
  public func setDisplayPreference(
    perspectivePersonID: UUID,
    targetPersonID: UUID,
    primaryFactID: UUID
  ) throws -> RelationshipDisplayPreference {
    let timestamp = now()

    if let existingPreference = try fetchDisplayPreference(
      perspectivePersonID: perspectivePersonID,
      targetPersonID: targetPersonID
    ) {
      existingPreference.primaryFactID = primaryFactID
      existingPreference.updatedAt = timestamp
      try context.save()
      return existingPreference
    }

    let preference = RelationshipDisplayPreference(
      perspectivePersonID: perspectivePersonID,
      targetPersonID: targetPersonID,
      primaryFactID: primaryFactID,
      createdAt: timestamp,
      updatedAt: timestamp
    )
    context.insert(preference)
    try context.save()
    return preference
  }

  public func clearDisplayPreference(perspectivePersonID: UUID, targetPersonID: UUID) throws {
    guard
      let preference = try fetchDisplayPreference(
        perspectivePersonID: perspectivePersonID,
        targetPersonID: targetPersonID
      )
    else {
      return
    }

    context.delete(preference)
    try context.save()
  }

  public func deleteReferences(toPersonID personID: UUID) throws {
    let factsDescriptor = FetchDescriptor<RelationshipFact>(
      predicate: #Predicate<RelationshipFact> { fact in
        fact.personAID == personID || fact.personBID == personID
      }
    )
    let preferencesDescriptor = FetchDescriptor<RelationshipDisplayPreference>(
      predicate: #Predicate<RelationshipDisplayPreference> { preference in
        preference.perspectivePersonID == personID || preference.targetPersonID == personID
      }
    )

    for fact in try context.fetch(factsDescriptor) {
      context.delete(fact)
    }

    for preference in try context.fetch(preferencesDescriptor) {
      context.delete(preference)
    }

    try context.save()
  }

  private func fetchFact(id: UUID) throws -> RelationshipFact {
    var descriptor = FetchDescriptor<RelationshipFact>(
      predicate: #Predicate<RelationshipFact> { fact in
        fact.id == id
      }
    )
    descriptor.fetchLimit = 1

    guard let fact = try context.fetch(descriptor).first else {
      throw RelationshipStoreError.factNotFound(id)
    }

    return fact
  }

  private func fetchMatchingFact(
    personAID: UUID,
    personBID: UUID,
    kind: RelationshipKind,
    personARole: RelationshipRole,
    personBRole: RelationshipRole
  ) throws -> RelationshipFact? {
    let kindRawValue = kind.rawValue
    let personARoleRawValue = personARole.rawValue
    let personBRoleRawValue = personBRole.rawValue
    var descriptor = FetchDescriptor<RelationshipFact>(
      predicate: #Predicate<RelationshipFact> { fact in
        fact.personAID == personAID
          && fact.personBID == personBID
          && fact.kindRawValue == kindRawValue
          && fact.personARoleRawValue == personARoleRawValue
          && fact.personBRoleRawValue == personBRoleRawValue
      }
    )
    descriptor.fetchLimit = 1

    return try context.fetch(descriptor).first
  }

  private func fetchDisplayPreference(
    perspectivePersonID: UUID,
    targetPersonID: UUID
  ) throws -> RelationshipDisplayPreference? {
    var descriptor = FetchDescriptor<RelationshipDisplayPreference>(
      predicate: #Predicate<RelationshipDisplayPreference> { preference in
        preference.perspectivePersonID == perspectivePersonID
          && preference.targetPersonID == targetPersonID
      }
    )
    descriptor.fetchLimit = 1

    return try context.fetch(descriptor).first
  }

  private func normalizedEndpointPair(
    personAID: UUID,
    personBID: UUID,
    personARole: RelationshipRole,
    personBRole: RelationshipRole
  ) throws -> NormalizedEndpointPair {
    guard personAID != personBID else {
      throw RelationshipStoreError.invalidSelfRelationship(personAID)
    }

    if personAID.uuidString <= personBID.uuidString {
      return NormalizedEndpointPair(
        personAID: personAID,
        personBID: personBID,
        personARole: personARole,
        personBRole: personBRole
      )
    }

    return NormalizedEndpointPair(
      personAID: personBID,
      personBID: personAID,
      personARole: personBRole,
      personBRole: personARole
    )
  }
}
