import Foundation

public enum BirthdayCalendarKind: String, CaseIterable, Codable, Identifiable, Sendable {
  case gregorian
  case buddhist
  case chinese
  case hebrew
  case islamicUmmAlQura

  public var id: String { rawValue }

  public var calendarIdentifier: Calendar.Identifier {
    switch self {
    case .gregorian: .gregorian
    case .buddhist: .buddhist
    case .chinese: .chinese
    case .hebrew: .hebrew
    case .islamicUmmAlQura: .islamicUmmAlQura
    }
  }

  public var calendar: Calendar {
    var calendar = Calendar(identifier: calendarIdentifier)
    calendar.timeZone = .autoupdatingCurrent
    calendar.locale = .autoupdatingCurrent
    return calendar
  }
}
