import Foundation

public struct Birthday: Codable, Equatable, Sendable {
  public var calendarKind: BirthdayCalendarKind
  public var era: Int?
  public var year: Int?
  public var month: Int
  public var day: Int

  public init(calendarKind: BirthdayCalendarKind, era: Int? = nil, year: Int? = nil, month: Int, day: Int) {
    self.calendarKind = calendarKind
    self.era = era
    self.year = year
    self.month = month
    self.day = day
  }

  public init(date: Date, calendarKind: BirthdayCalendarKind) {
    let calendar = calendarKind.calendar
    let components = calendar.dateComponents([.era, .year, .month, .day], from: date)
    self.init(
      calendarKind: calendarKind,
      era: components.era,
      year: components.year,
      month: components.month ?? 1,
      day: components.day ?? 1
    )
  }
}
