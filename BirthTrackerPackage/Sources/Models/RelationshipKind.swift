import Foundation

public enum RelationshipKind: String, CaseIterable, Codable, Sendable {
  case parentChild
  case sibling
  case spouse
  case friend
  case classmate
  case coworker

  /// 是否参与亲属关系推断；只有亲属关系会被用来推导爷孙、叔侄、堂表亲等称谓。
  public var participatesInKinshipInference: Bool {
    switch self {
    case .parentChild, .sibling, .spouse:
      true
    case .friend, .classmate, .coworker:
      false
    }
  }
}
