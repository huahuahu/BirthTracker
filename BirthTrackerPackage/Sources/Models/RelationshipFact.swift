import Foundation
import SwiftData

@Model
public final class RelationshipFact {
  public var id: UUID = UUID()
  public var personAID: UUID = UUID()
  public var personBID: UUID = UUID()
  public var kindRawValue: String = RelationshipKind.friend.rawValue
  public var personARoleRawValue: String = RelationshipRole.friend.rawValue
  public var personBRoleRawValue: String = RelationshipRole.friend.rawValue
  public var notes: String = ""
  public var createdAt: Date = Date()
  public var updatedAt: Date = Date()

  public init(
    id: UUID = UUID(),
    personAID: UUID,
    personBID: UUID,
    kind: RelationshipKind,
    personARole: RelationshipRole,
    personBRole: RelationshipRole,
    notes: String = "",
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.personAID = personAID
    self.personBID = personBID
    self.kindRawValue = kind.rawValue
    self.personARoleRawValue = personARole.rawValue
    self.personBRoleRawValue = personBRole.rawValue
    self.notes = notes
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension RelationshipFact {
  public var kind: RelationshipKind {
    get { RelationshipKind(rawValue: kindRawValue) ?? .friend }
    set { kindRawValue = newValue.rawValue }
  }

  public var personARole: RelationshipRole {
    get { RelationshipRole(rawValue: personARoleRawValue) ?? .friend }
    set { personARoleRawValue = newValue.rawValue }
  }

  public var personBRole: RelationshipRole {
    get { RelationshipRole(rawValue: personBRoleRawValue) ?? .friend }
    set { personBRoleRawValue = newValue.rawValue }
  }
}
