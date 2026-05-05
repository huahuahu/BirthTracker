import Foundation

public struct UpcomingBirthday: Codable, Identifiable, Equatable, Sendable {
  public var id: UUID
  public var personName: String
  public var date: Date
  public var age: Int?
  public var calendarKind: BirthdayCalendarKind

  public init(id: UUID, personName: String, date: Date, age: Int?, calendarKind: BirthdayCalendarKind) {
    self.id = id
    self.personName = personName
    self.date = date
    self.age = age
    self.calendarKind = calendarKind
  }
}
