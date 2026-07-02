import Foundation
import SwiftData

@Model
public final class RelationshipDisplayPreference {
  public var id: UUID = UUID()
  public var perspectivePersonID: UUID = UUID()
  public var targetPersonID: UUID = UUID()
  public var primaryFactID: UUID?
  public var createdAt: Date = Date()
  public var updatedAt: Date = Date()

  public init(
    id: UUID = UUID(),
    perspectivePersonID: UUID,
    targetPersonID: UUID,
    primaryFactID: UUID?,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.perspectivePersonID = perspectivePersonID
    self.targetPersonID = targetPersonID
    self.primaryFactID = primaryFactID
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}
