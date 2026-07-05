import Foundation

public struct ContactAgeSnapshotMetrics: Equatable, Sendable {
  public var birthDuration: PersonBirthdaySummary.BirthDuration
  public var totalBirthDays: Int

  public init(
    birthDuration: PersonBirthdaySummary.BirthDuration,
    totalBirthDays: Int
  ) {
    self.birthDuration = birthDuration
    self.totalBirthDays = totalBirthDays
  }

  public static func make(
    birthDate: Date,
    calendarKind: BirthdayCalendarKind,
    referenceDate: Date
  ) -> ContactAgeSnapshotMetrics {
    let calendar = calendarKind.calendar
    let birthStart = calendar.startOfDay(for: birthDate)
    let referenceStart = calendar.startOfDay(for: referenceDate)

    guard birthStart <= referenceStart else {
      return ContactAgeSnapshotMetrics(
        birthDuration: PersonBirthdaySummary.BirthDuration(years: 0, months: 0, days: 0),
        totalBirthDays: 0)
    }

    let durationComponents = calendar.dateComponents([.year, .month, .day], from: birthStart, to: referenceStart)
    let totalDays = calendar.dateComponents([.day], from: birthStart, to: referenceStart).day ?? 0

    return ContactAgeSnapshotMetrics(
      birthDuration: PersonBirthdaySummary.BirthDuration(
        years: max(0, durationComponents.year ?? 0),
        months: max(0, durationComponents.month ?? 0),
        days: max(0, durationComponents.day ?? 0)),
      totalBirthDays: max(0, totalDays))
  }

  public static func make(
    snapshot: WidgetPersonSnapshot,
    referenceDate: Date
  ) -> ContactAgeSnapshotMetrics? {
    if let birthDate = snapshot.birthDate {
      return make(
        birthDate: birthDate,
        calendarKind: snapshot.calendarKind,
        referenceDate: referenceDate)
    }

    guard snapshot.schemaVersion < WidgetSnapshotSchema.currentVersion else { return nil }
    guard let birthDuration = snapshot.birthDuration else { return nil }
    guard let totalBirthDays = snapshot.totalBirthDays else { return nil }

    return ContactAgeSnapshotMetrics(
      birthDuration: birthDuration,
      totalBirthDays: totalBirthDays)
  }
}
