import Foundation

public enum RelationshipKind: String, CaseIterable, Codable, Sendable {
  case parentChild
  case sibling
  case spouse
  case friend
  case classmate
  case coworker

  public var participatesInKinshipInference: Bool {
    switch self {
    case .parentChild, .sibling, .spouse:
      true
    case .friend, .classmate, .coworker:
      false
    }
  }
}
