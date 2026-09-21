import Foundation
import Models

struct UpcomingBirthdayDateFormatter {
  static func string(
    for date: Date,
    calendarKind: BirthdayCalendarKind,
    locale: Locale = .autoupdatingCurrent,
    timeZone: TimeZone = .autoupdatingCurrent
  ) -> String {
    var calendar = Calendar(identifier: calendarKind.calendarIdentifier)
    calendar.locale = locale
    calendar.timeZone = timeZone

    var formatStyle = Date.FormatStyle()
      .month(.abbreviated)
      .day()
    formatStyle.locale = locale
    formatStyle.calendar = calendar
    formatStyle.timeZone = timeZone
    return date.formatted(formatStyle)
  }
}
