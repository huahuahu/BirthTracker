import Foundation
import Models

struct ContactAgeDurationFormatter {
  func string(
    from birthDate: Date,
    to referenceDate: Date,
    calendarKind: BirthdayCalendarKind,
    displayFormat: ContactAgeDisplayFormat,
    locale: Locale = .autoupdatingCurrent
  ) -> String? {
    var calendar = calendarKind.calendar
    calendar.locale = locale
    let birthStart = calendar.startOfDay(for: birthDate)
    let referenceStart = calendar.startOfDay(for: referenceDate)

    let formatter = DateComponentsFormatter()
    formatter.calendar = calendar
    formatter.unitsStyle = .full
    switch displayFormat {
    case .yearMonthDay:
      formatter.allowedUnits = [.year, .month, .day]
    case .monthDay:
      formatter.allowedUnits = [.month, .day]
    case .day:
      formatter.allowedUnits = [.day]
    }
    return formatter.string(from: min(birthStart, referenceStart), to: referenceStart)
  }
}
