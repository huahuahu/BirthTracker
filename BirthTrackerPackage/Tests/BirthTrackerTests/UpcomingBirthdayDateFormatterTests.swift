import Foundation
import Models
import Testing

@testable import BirthTrackerWidgets

struct UpcomingBirthdayDateFormatterTests {
  @Test(
    "Upcoming birthday formats the same absolute date in the selected calendar",
    .bug("https://github.com/huahuahu/BirthTracker/issues/43"))
  func dateFormattingUsesSelectedCalendar() throws {
    let timeZone = try #require(TimeZone(secondsFromGMT: 0))
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let date = try #require(
      calendar.date(from: DateComponents(year: 2025, month: 1, day: 29, hour: 12)))
    let locale = Locale(identifier: "en_US")

    let gregorianText = UpcomingBirthdayDateFormatter.string(
      for: date,
      calendarKind: .gregorian,
      locale: locale,
      timeZone: timeZone)
    let chineseText = UpcomingBirthdayDateFormatter.string(
      for: date,
      calendarKind: .chinese,
      locale: locale,
      timeZone: timeZone)

    #expect(gregorianText == "Jan 29")
    #expect(chineseText == "Mo1 1")
  }
}
