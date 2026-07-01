import Foundation

public struct WidgetBirthdayPresentation: Equatable, Identifiable, Sendable {
  public var id: UUID { birthday.id }

  public let birthday: UpcomingBirthday
  public let daysUntil: Int

  public init(birthday: UpcomingBirthday, daysUntil: Int) {
    self.birthday = birthday
    self.daysUntil = max(0, daysUntil)
  }

  public static func make(
    for birthday: UpcomingBirthday,
    referenceDate: Date,
    calendar: Calendar = .current
  ) -> WidgetBirthdayPresentation {
    let referenceStart = calendar.startOfDay(for: referenceDate)
    let birthdayStart = calendar.startOfDay(for: birthday.date)
    let days = calendar.dateComponents([.day], from: referenceStart, to: birthdayStart).day ?? 0
    return WidgetBirthdayPresentation(birthday: birthday, daysUntil: days)
  }
}
