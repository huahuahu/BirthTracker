import Foundation
import SwiftData

@Model
public final class RelationshipFact {
  /// 关系事实的稳定业务标识。
  public private(set) var id: UUID = UUID()
  /// 关系端点 A 的人物 ID；A/B 只表示端点槽位，不表示方向。
  public private(set) var personAID: UUID = UUID()
  /// 关系端点 B 的人物 ID；A/B 只表示端点槽位，不表示方向。
  public private(set) var personBID: UUID = UUID()
  /// 关系类型原始值，例如父子、兄弟姐妹、同学。
  private(set) var kindRawValue: String = RelationshipKind.friend.rawValue
  /// 端点 A 在这条关系里的角色原始值。
  private(set) var personARoleRawValue: String = RelationshipRole.friend.rawValue
  /// 端点 B 在这条关系里的角色原始值。
  private(set) var personBRoleRawValue: String = RelationshipRole.friend.rawValue
  /// 端点 A 作为视角看端点 B 时，这条关系是否优先展示。
  public private(set) var isPrimaryFromPersonA: Bool = false
  /// 端点 B 作为视角看端点 A 时，这条关系是否优先展示。
  public private(set) var isPrimaryFromPersonB: Bool = false
  /// 用户为这条关系记录的备注。
  public private(set) var notes: String = ""
  /// 关系事实创建时间。
  public private(set) var createdAt: Date = Date()
  /// 关系事实最后更新时间，由 RelationshipStore 显式维护。
  public private(set) var updatedAt: Date = Date()

  init(
    id: UUID = UUID(),
    personAID: UUID,
    personBID: UUID,
    kind: RelationshipKind,
    personARole: RelationshipRole,
    personBRole: RelationshipRole,
    isPrimaryFromPersonA: Bool = false,
    isPrimaryFromPersonB: Bool = false,
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
    self.isPrimaryFromPersonA = isPrimaryFromPersonA
    self.isPrimaryFromPersonB = isPrimaryFromPersonB
    self.notes = notes
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

extension RelationshipFact {
  public var kind: RelationshipKind {
    RelationshipKind(rawValue: kindRawValue) ?? .friend
  }

  public var personARole: RelationshipRole {
    RelationshipRole(rawValue: personARoleRawValue) ?? .friend
  }

  public var personBRole: RelationshipRole {
    RelationshipRole(rawValue: personBRoleRawValue) ?? .friend
  }

  public func connects(_ firstPersonID: UUID, and secondPersonID: UUID) -> Bool {
    (personAID == firstPersonID && personBID == secondPersonID)
      || (personAID == secondPersonID && personBID == firstPersonID)
  }

  public func isPrimary(from perspectivePersonID: UUID) -> Bool {
    if personAID == perspectivePersonID {
      return isPrimaryFromPersonA
    }
    if personBID == perspectivePersonID {
      return isPrimaryFromPersonB
    }
    return false
  }

  func replaceDetails(
    personAID: UUID,
    personBID: UUID,
    kind: RelationshipKind,
    personARole: RelationshipRole,
    personBRole: RelationshipRole,
    updatedAt: Date
  ) {
    self.personAID = personAID
    self.personBID = personBID
    kindRawValue = kind.rawValue
    personARoleRawValue = personARole.rawValue
    personBRoleRawValue = personBRole.rawValue
    self.updatedAt = updatedAt
  }

  func replaceNotes(_ notes: String, updatedAt: Date) {
    self.notes = notes
    self.updatedAt = updatedAt
  }

  @discardableResult
  func setPrimary(_ isPrimary: Bool, from perspectivePersonID: UUID, updatedAt: Date) -> Bool {
    if personAID == perspectivePersonID {
      let changed = isPrimaryFromPersonA != isPrimary
      isPrimaryFromPersonA = isPrimary
      if changed {
        self.updatedAt = updatedAt
      }
      return changed
    }
    if personBID == perspectivePersonID {
      let changed = isPrimaryFromPersonB != isPrimary
      isPrimaryFromPersonB = isPrimary
      if changed {
        self.updatedAt = updatedAt
      }
      return changed
    }
    return false
  }
}
