import Foundation

public struct WidgetSnapshot: Codable, Equatable, Sendable {
  public var generatedAt: Date
  public var birthdays: [UpcomingBirthday]

  public init(generatedAt: Date = .now, birthdays: [UpcomingBirthday]) {
    self.generatedAt = generatedAt
    self.birthdays = birthdays
  }
}
