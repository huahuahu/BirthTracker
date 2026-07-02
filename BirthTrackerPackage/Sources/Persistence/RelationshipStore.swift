import Foundation
import Models
import SwiftData

public enum RelationshipStoreError: Error, Equatable {
  case duplicateFact
  case factNotFound(UUID)
  case invalidSelfRelationship(UUID)
  case invalidRoleCombination(
    kind: RelationshipKind,
    personARole: RelationshipRole,
    personBRole: RelationshipRole)
  case unrelatedPrimaryFact(
    primaryFactID: UUID,
    perspectivePersonID: UUID,
    targetPersonID: UUID)
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
    try validateRoleCombination(
      kind: kind,
      personARole: normalized.personARole,
      personBRole: normalized.personBRole)

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
    try validateRoleCombination(
      kind: kind,
      personARole: normalized.personARole,
      personBRole: normalized.personBRole)

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
    try validatePrimaryFact(
      primaryFactID,
      connects: perspectivePersonID,
      and: targetPersonID)

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
    try deleteReferences(toPersonID: personID, save: true)
  }

  func deleteReferences(toPersonID personID: UUID, save: Bool) throws {
    let factsDescriptor = FetchDescriptor<RelationshipFact>(
      predicate: #Predicate<RelationshipFact> { fact in
        fact.personAID == personID || fact.personBID == personID
      }
    )
    let deletedFacts = try context.fetch(factsDescriptor)
    let deletedFactIDs = Set(deletedFacts.map(\.id))
    let preferencesDescriptor = FetchDescriptor<RelationshipDisplayPreference>()

    for preference in try context.fetch(preferencesDescriptor) {
      let referencesDeletedPerson = preference.perspectivePersonID == personID || preference.targetPersonID == personID
      let referencesDeletedFact = preference.primaryFactID.map(deletedFactIDs.contains) == true

      if referencesDeletedPerson || referencesDeletedFact {
        context.delete(preference)
      }
    }

    for fact in deletedFacts {
      context.delete(fact)
    }

    if save {
      try context.save()
    }
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

  private func validateRoleCombination(
    kind: RelationshipKind,
    personARole: RelationshipRole,
    personBRole: RelationshipRole
  ) throws {
    let isValid =
      switch kind {
      case .parentChild:
        (personARole == .parent && personBRole == .child)
          || (personARole == .child && personBRole == .parent)
      case .sibling:
        personARole == .sibling && personBRole == .sibling
      case .spouse:
        personARole == .spouse && personBRole == .spouse
      case .friend:
        personARole == .friend && personBRole == .friend
      case .classmate:
        personARole == .classmate && personBRole == .classmate
      case .coworker:
        personARole == .coworker && personBRole == .coworker
      }

    guard isValid else {
      throw RelationshipStoreError.invalidRoleCombination(
        kind: kind,
        personARole: personARole,
        personBRole: personBRole)
    }
  }

  private func validatePrimaryFact(
    _ primaryFactID: UUID,
    connects perspectivePersonID: UUID,
    and targetPersonID: UUID
  ) throws {
    let primaryFact = try fetchFact(id: primaryFactID)
    let connectsRequestedPair =
      (primaryFact.personAID == perspectivePersonID && primaryFact.personBID == targetPersonID)
      || (primaryFact.personAID == targetPersonID && primaryFact.personBID == perspectivePersonID)

    guard connectsRequestedPair else {
      throw RelationshipStoreError.unrelatedPrimaryFact(
        primaryFactID: primaryFactID,
        perspectivePersonID: perspectivePersonID,
        targetPersonID: targetPersonID)
    }
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
