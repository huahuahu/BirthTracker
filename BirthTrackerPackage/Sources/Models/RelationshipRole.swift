import Foundation

public enum RelationshipRole: String, CaseIterable, Codable, Sendable {
  case parent
  case child
  case sibling
  case spouse
  case friend
  case classmate
  case coworker
}
