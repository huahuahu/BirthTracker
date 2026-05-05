import Foundation
import SwiftData

@Model
final class TrackedPerson {
  var id: UUID = UUID()
  var name: String = ""
  var notes: String = ""
  var calendarKindRawValue: String = BirthdayCalendarKind.gregorian.rawValue
  var birthEra: Int?
  var birthYear: Int?
  var birthMonth: Int = 1
  var birthDay: Int = 1
  var createdAt: Date = Date()
  var updatedAt: Date = Date()

  init(id: UUID = UUID(), name: String, birthday: Birthday, notes: String = "") {
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
  var calendarKind: BirthdayCalendarKind {
    get { BirthdayCalendarKind(rawValue: calendarKindRawValue) ?? .gregorian }
    set { calendarKindRawValue = newValue.rawValue }
  }

  var birthday: Birthday {
    Birthday(calendarKind: calendarKind, era: birthEra, year: birthYear, month: birthMonth, day: birthDay)
  }

  func upcomingBirthday(after referenceDate: Date = .now) -> UpcomingBirthday? {
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
