import Foundation
import Models
import Persistence

struct ContactAgeDurationFormatter {
  func string(
    for metrics: ContactAgeSnapshotMetrics,
    displayFormat: ContactAgeDisplayFormat
  ) -> String? {
    switch displayFormat {
    case .yearMonthDay:
      return string(
        from: DateComponents(
          year: metrics.birthDuration.years,
          month: metrics.birthDuration.months,
          day: metrics.birthDuration.days),
        allowedUnits: [.year, .month, .day])
    case .monthDay:
      let monthDay = metrics.totalBirthMonthsAndDays
      return string(
        from: DateComponents(month: monthDay.months, day: monthDay.days),
        allowedUnits: [.month, .day])
    case .day:
      return string(
        from: DateComponents(day: metrics.totalBirthDays),
        allowedUnits: [.day])
    }
  }

  private func string(
    from components: DateComponents,
    allowedUnits: NSCalendar.Unit
  ) -> String? {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = allowedUnits
    formatter.unitsStyle = .full
    return formatter.string(from: components)
  }
}
