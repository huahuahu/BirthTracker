import Foundation

public struct PersonBirthdaySummary: Equatable, Sendable {
  public struct BirthDuration: Codable, Equatable, Sendable {
    public var years: Int
    public var months: Int
    public var days: Int

    public init(years: Int, months: Int, days: Int) {
      self.years = years
      self.months = months
      self.days = days
    }
  }

  public var personID: UUID
  public var personName: String
  public var calendarKind: BirthdayCalendarKind
  public var birthDate: Date?
  public var birthDuration: BirthDuration?
  public var nextBirthdayDate: Date?
  public var daysUntilNextBirthday: Int?
  public var totalBirthDays: Int?
  public var nextAge: Int?

  public init(
    personID: UUID,
    personName: String,
    calendarKind: BirthdayCalendarKind,
    birthDate: Date?,
    birthDuration: BirthDuration?,
    nextBirthdayDate: Date?,
    daysUntilNextBirthday: Int?,
    totalBirthDays: Int?,
    nextAge: Int?
  ) {
    self.personID = personID
    self.personName = personName
    self.calendarKind = calendarKind
    self.birthDate = birthDate
    self.birthDuration = birthDuration
    self.nextBirthdayDate = nextBirthdayDate
    self.daysUntilNextBirthday = daysUntilNextBirthday
    self.totalBirthDays = totalBirthDays
    self.nextAge = nextAge
  }

  public static func make(
    for person: TrackedPerson,
    referenceDate: Date = .now
  ) -> PersonBirthdaySummary {
    guard let birthday = person.birthday else {
      return PersonBirthdaySummary(
        personID: person.id,
        personName: person.name,
        calendarKind: person.calendarKind,
        birthDate: nil,
        birthDuration: nil,
        nextBirthdayDate: nil,
        daysUntilNextBirthday: nil,
        totalBirthDays: nil,
        nextAge: nil)
    }

    var calendar = birthday.calendarKind.calendar
    calendar.timeZone = .autoupdatingCurrent
    let birthDate = makeBirthDate(for: birthday, calendar: calendar)
    let nextBirthdayDate = BirthdayCalculator.nextOccurrence(for: birthday, after: referenceDate)

    return PersonBirthdaySummary(
      personID: person.id,
      personName: person.name,
      calendarKind: birthday.calendarKind,
      birthDate: birthDate,
      birthDuration: birthDate.map { birthDuration(from: $0, to: referenceDate, calendar: calendar) },
      nextBirthdayDate: nextBirthdayDate,
      daysUntilNextBirthday: nextBirthdayDate.map { daysUntil($0, from: referenceDate, calendar: calendar) },
      totalBirthDays: birthDate.map { totalBirthDays(from: $0, to: referenceDate, calendar: calendar) },
      nextAge: nextBirthdayDate.flatMap { BirthdayCalculator.age(on: $0, for: birthday) })
  }

  private static func makeBirthDate(for birthday: Birthday, calendar: Calendar) -> Date? {
    guard let year = birthday.year else { return nil }

    var components = DateComponents()
    components.calendar = calendar
    components.era = birthday.era
    components.year = year
    components.month = birthday.month
    components.day = birthday.day
    components.hour = 12
    return calendar.date(from: components)
  }

  private static func birthDuration(
    from birthDate: Date,
    to referenceDate: Date,
    calendar: Calendar
  ) -> BirthDuration {
    let birthStart = calendar.startOfDay(for: birthDate)
    let referenceStart = calendar.startOfDay(for: referenceDate)
    guard birthStart <= referenceStart else {
      return BirthDuration(years: 0, months: 0, days: 0)
    }

    let components = calendar.dateComponents([.year, .month, .day], from: birthStart, to: referenceStart)
    return BirthDuration(
      years: max(0, components.year ?? 0),
      months: max(0, components.month ?? 0),
      days: max(0, components.day ?? 0))
  }

  private static func totalBirthDays(
    from birthDate: Date,
    to referenceDate: Date,
    calendar: Calendar
  ) -> Int {
    let birthStart = calendar.startOfDay(for: birthDate)
    let referenceStart = calendar.startOfDay(for: referenceDate)
    guard birthStart <= referenceStart else { return 0 }

    return max(0, calendar.dateComponents([.day], from: birthStart, to: referenceStart).day ?? 0)
  }

  private static func daysUntil(
    _ nextBirthdayDate: Date,
    from referenceDate: Date,
    calendar: Calendar
  ) -> Int {
    let referenceStart = calendar.startOfDay(for: referenceDate)
    let nextStart = calendar.startOfDay(for: nextBirthdayDate)
    return max(0, calendar.dateComponents([.day], from: referenceStart, to: nextStart).day ?? 0)
  }
}
