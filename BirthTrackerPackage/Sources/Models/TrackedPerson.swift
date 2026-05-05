import Foundation
import SwiftData

@Model
public final class TrackedPerson {
  public var id: UUID = UUID()
  public var name: String = ""
  public var notes: String = ""
  public var calendarKindRawValue: String = BirthdayCalendarKind.gregorian.rawValue
  public var birthEra: Int?
  public var birthYear: Int?
  public var birthMonth: Int = 1
  public var birthDay: Int = 1
  public var createdAt: Date = Date()
  public var updatedAt: Date = Date()

  public init(id: UUID = UUID(), name: String, birthday: Birthday, notes: String = "") {
    self.id = id
    self.name = name
    self.notes = notes
    self.calendarKindRawValue = birthday.calendarKind.rawValue
    self.birthEra = birthday.era
    self.birthYear = birthday.year
    self.birthMonth = birthday.month
    self.birthDay = birthday.day
  }
}

extension TrackedPerson {
  public var calendarKind: BirthdayCalendarKind {
    get { BirthdayCalendarKind(rawValue: calendarKindRawValue) ?? .gregorian }
    set { calendarKindRawValue = newValue.rawValue }
  }

  public var birthday: Birthday {
    Birthday(calendarKind: calendarKind, era: birthEra, year: birthYear, month: birthMonth, day: birthDay)
  }

  public func upcomingBirthday(after referenceDate: Date = .now) -> UpcomingBirthday? {
    guard let nextDate = BirthdayCalculator.nextOccurrence(for: birthday, after: referenceDate) else { return nil }

    return UpcomingBirthday(
      id: id,
      personName: name,
      date: nextDate,
      age: BirthdayCalculator.age(on: nextDate, for: birthday),
      calendarKind: calendarKind
    )
  }
}
