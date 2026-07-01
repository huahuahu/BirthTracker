import Foundation

public struct WidgetUpcomingBirthdaysDisplay: Equatable, Sendable {
  public let referenceDate: Date
  public let birthdays: [UpcomingBirthday]

  public init(referenceDate: Date, birthdays: [UpcomingBirthday]) {
    self.referenceDate = referenceDate
    self.birthdays = birthdays
  }

  public static func make(
    from snapshots: [WidgetPersonSnapshot],
    displayDate: Date
  ) -> WidgetUpcomingBirthdaysDisplay {
    WidgetUpcomingBirthdaysDisplay(
      referenceDate: displayDate,
      birthdays: snapshots.map(\.upcomingBirthday))
  }
}
