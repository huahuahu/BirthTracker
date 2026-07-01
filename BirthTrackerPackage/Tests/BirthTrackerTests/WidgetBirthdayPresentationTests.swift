import Foundation
import Models
import Testing

@Suite("Widget birthday presentation")
struct WidgetBirthdayPresentationTests {
  private var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
    return calendar
  }

  @Test("Birthday happening today has zero days until")
  func todayCountdownIsZero() throws {
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 15)))
    let birthday = try makeBirthday(dayOffset: 0, age: 30, referenceDate: referenceDate)

    let presentation = WidgetBirthdayPresentation.make(
      for: birthday,
      referenceDate: referenceDate,
      calendar: calendar)

    #expect(presentation.id == birthday.id)
    #expect(presentation.birthday == birthday)
    #expect(presentation.daysUntil == 0)
  }

  @Test("Birthday tomorrow has one day until")
  func tomorrowCountdownIsOne() throws {
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 23)))
    let birthday = try makeBirthday(dayOffset: 1, age: 31, referenceDate: referenceDate)

    let presentation = WidgetBirthdayPresentation.make(
      for: birthday,
      referenceDate: referenceDate,
      calendar: calendar)

    #expect(presentation.daysUntil == 1)
  }

  @Test("Future birthday uses calendar day distance")
  func futureCountdownUsesCalendarDayDistance() throws {
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 8)))
    let birthday = try makeBirthday(dayOffset: 8, age: nil, referenceDate: referenceDate)

    let presentation = WidgetBirthdayPresentation.make(
      for: birthday,
      referenceDate: referenceDate,
      calendar: calendar)

    #expect(presentation.daysUntil == 8)
    #expect(presentation.birthday.age == nil)
  }

  @Test("Past birthday display clamps to today")
  func pastBirthdayClampsToToday() throws {
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 8)))
    let birthday = try makeBirthday(dayOffset: -2, age: 30, referenceDate: referenceDate)

    let presentation = WidgetBirthdayPresentation.make(
      for: birthday,
      referenceDate: referenceDate,
      calendar: calendar)

    #expect(presentation.daysUntil == 0)
  }

  @Test("Widget display uses current refresh date instead of stale snapshot generation date")
  func widgetDisplayUsesCurrentRefreshDateForCountdown() throws {
    let snapshotGeneratedAt = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)))
    let displayDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 10, hour: 9)))
    let personID = UUID()
    let snapshot = WidgetPersonSnapshot(
      personID: personID,
      displayName: "Taylor",
      nextBirthdayDate: displayDate,
      age: 30,
      calendarKind: .gregorian,
      generatedAt: snapshotGeneratedAt,
      sortIndex: 0)

    let display = WidgetUpcomingBirthdaysDisplay.make(
      from: [snapshot],
      displayDate: displayDate)
    let presentation = WidgetBirthdayPresentation.make(
      for: try #require(display.birthdays.first),
      referenceDate: display.referenceDate,
      calendar: calendar)

    #expect(display.referenceDate == displayDate)
    #expect(presentation.daysUntil == 0)
  }

  private func makeBirthday(
    dayOffset: Int,
    age: Int?,
    referenceDate: Date
  ) throws -> UpcomingBirthday {
    let date = try #require(calendar.date(byAdding: .day, value: dayOffset, to: referenceDate))
    return UpcomingBirthday(
      id: UUID(),
      personName: "Taylor",
      date: date,
      age: age,
      calendarKind: .gregorian)
  }
}
