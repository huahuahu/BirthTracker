import Foundation

public enum BirthdayCalculator {
  public static func nextOccurrence(
    for birthday: Birthday,
    after referenceDate: Date = .now
  ) -> Date? {
    var calendar = birthday.calendarKind.calendar
    calendar.timeZone = .autoupdatingCurrent

    let referenceComponents = calendar.dateComponents([.era, .year, .month, .day], from: referenceDate)
    guard let referenceYear = referenceComponents.year else { return nil }

    for yearOffset in 0...2 {
      var components = DateComponents()
      components.calendar = calendar
      components.era = birthday.era ?? referenceComponents.era
      components.year = referenceYear + yearOffset
      components.month = birthday.month
      components.day = birthday.day
      components.hour = 12

      if let candidate = calendar.date(from: components), candidate >= calendar.startOfDay(for: referenceDate) {
        return candidate
      }
    }

    return nil
  }

  public static func age(on occurrence: Date, for birthday: Birthday) -> Int? {
    guard let birthYear = birthday.year else { return nil }
    let calendar = birthday.calendarKind.calendar
    let occurrenceYear = calendar.component(.year, from: occurrence)
    return max(0, occurrenceYear - birthYear)
  }
}
