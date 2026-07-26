import Foundation
import Models
import Persistence

struct ContactAgeDurationFormatter {
  func string(
    for metrics: ContactAgeSnapshotMetrics,
    displayFormat: ContactAgeDisplayFormat,
    locale: Locale = .autoupdatingCurrent
  ) -> String? {
    switch displayFormat {
    case .yearMonthDay:
      return string(
        from: DateComponents(
          year: metrics.birthDuration.years,
          month: metrics.birthDuration.months,
          day: metrics.birthDuration.days),
        allowedUnits: [.year, .month, .day],
        locale: locale)
    case .monthDay:
      let monthDay = metrics.totalBirthMonthsAndDays
      return string(
        from: DateComponents(month: monthDay.months, day: monthDay.days),
        allowedUnits: [.month, .day],
        locale: locale)
    case .day:
      return string(
        from: DateComponents(day: metrics.totalBirthDays),
        allowedUnits: [.day],
        locale: locale)
    }
  }

  private func string(
    from components: DateComponents,
    allowedUnits: NSCalendar.Unit,
    locale: Locale
  ) -> String? {
    let formatter = DateComponentsFormatter()
    var calendar = Calendar.autoupdatingCurrent
    calendar.locale = locale
    formatter.calendar = calendar
    formatter.allowedUnits = allowedUnits
    formatter.unitsStyle = .full
    return formatter.string(from: components)
  }
}
