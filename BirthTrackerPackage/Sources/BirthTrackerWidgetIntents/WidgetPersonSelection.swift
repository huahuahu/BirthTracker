import Foundation

public struct WidgetPersonSelection: Equatable, Sendable {
  private static let separator = "::"

  public let personID: UUID
  public let widgetInstanceID: UUID?

  public init(personID: UUID, widgetInstanceID: UUID) {
    self.personID = personID
    self.widgetInstanceID = widgetInstanceID
  }

  public init?(rawValue: String) {
    let components = rawValue.components(separatedBy: Self.separator)
    guard let personID = UUID(uuidString: components[0]) else { return nil }

    switch components.count {
    case 1:
      self.personID = personID
      self.widgetInstanceID = nil
    case 2:
      guard let widgetInstanceID = UUID(uuidString: components[1]) else { return nil }
      self.personID = personID
      self.widgetInstanceID = widgetInstanceID
    default:
      return nil
    }
  }

  public var rawValue: String {
    guard let widgetInstanceID else { return personID.uuidString }
    return personID.uuidString + Self.separator + widgetInstanceID.uuidString
  }
}
