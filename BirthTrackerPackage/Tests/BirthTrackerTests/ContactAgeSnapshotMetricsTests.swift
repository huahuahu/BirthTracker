import Foundation
import Models
import Testing

struct ContactAgeSnapshotMetricsTests {
  @Test("Contact age metrics calculate duration and total days before birthday")
  func contactAgeMetricsBeforeBirthday() throws {
    let calendar = Calendar(identifier: .gregorian)
    let birthDate = try #require(calendar.date(from: DateComponents(year: 2024, month: 7, day: 5, hour: 12)))
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 10)))

    let metrics = ContactAgeSnapshotMetrics.make(
      birthDate: birthDate,
      calendarKind: .gregorian,
      referenceDate: referenceDate)

    #expect(metrics.birthDuration == PersonBirthdaySummary.BirthDuration(years: 1, months: 9, days: 26))
    #expect(metrics.totalBirthMonthsAndDays == ContactAgeSnapshotMetrics.BirthMonthDayDuration(months: 21, days: 26))
    #expect(metrics.totalBirthDays == 665)
  }

  @Test("Contact age metrics calculate duration and total days on birthday")
  func contactAgeMetricsOnBirthday() throws {
    let calendar = Calendar(identifier: .gregorian)
    let birthDate = try #require(calendar.date(from: DateComponents(year: 2024, month: 7, day: 5, hour: 12)))
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 5, hour: 10)))

    let metrics = ContactAgeSnapshotMetrics.make(
      birthDate: birthDate,
      calendarKind: .gregorian,
      referenceDate: referenceDate)

    #expect(metrics.birthDuration == PersonBirthdaySummary.BirthDuration(years: 2, months: 0, days: 0))
    #expect(metrics.totalBirthMonthsAndDays == ContactAgeSnapshotMetrics.BirthMonthDayDuration(months: 24, days: 0))
    #expect(metrics.totalBirthDays == 730)
  }

  @Test("Contact age metrics clamp future birth dates to zero")
  func contactAgeMetricsClampFutureBirthDatesToZero() throws {
    let calendar = Calendar(identifier: .gregorian)
    let birthDate = try #require(calendar.date(from: DateComponents(year: 2027, month: 1, day: 1, hour: 12)))
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 10)))

    let metrics = ContactAgeSnapshotMetrics.make(
      birthDate: birthDate,
      calendarKind: .gregorian,
      referenceDate: referenceDate)

    #expect(metrics.birthDuration == PersonBirthdaySummary.BirthDuration(years: 0, months: 0, days: 0))
    #expect(metrics.totalBirthMonthsAndDays == ContactAgeSnapshotMetrics.BirthMonthDayDuration(months: 0, days: 0))
    #expect(metrics.totalBirthDays == 0)
  }

  @Test("Contact age metrics fall back to legacy precomputed values")
  func contactAgeMetricsFallBackToLegacyPrecomputedValues() throws {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 10)))
    let legacySnapshot = WidgetPersonSnapshot(
      personID: UUID(),
      displayName: "Legacy Person",
      nextBirthdayDate: referenceDate,
      age: 2,
      birthDuration: PersonBirthdaySummary.BirthDuration(years: 1, months: 9, days: 26),
      daysUntilNextBirthday: 65,
      totalBirthDays: 665,
      calendarKind: .gregorian,
      schemaVersion: 3,
      generatedAt: referenceDate,
      sortIndex: 0)

    let metrics = try #require(
      ContactAgeSnapshotMetrics.make(snapshot: legacySnapshot, referenceDate: referenceDate))

    #expect(metrics.birthDuration == PersonBirthdaySummary.BirthDuration(years: 1, months: 9, days: 26))
    #expect(metrics.totalBirthDays == 665)
  }

  @Test("Contact age metrics do not fall back for current snapshots without birth date")
  func contactAgeMetricsDoNotFallBackForCurrentSnapshotsWithoutBirthDate() throws {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 10)))
    let currentSnapshot = WidgetPersonSnapshot(
      personID: UUID(),
      displayName: "Unknown Year",
      nextBirthdayDate: referenceDate,
      age: nil,
      birthDuration: PersonBirthdaySummary.BirthDuration(years: 1, months: 9, days: 26),
      daysUntilNextBirthday: 65,
      totalBirthDays: 665,
      calendarKind: .gregorian,
      generatedAt: referenceDate,
      sortIndex: 0)

    #expect(ContactAgeSnapshotMetrics.make(snapshot: currentSnapshot, referenceDate: referenceDate) == nil)
  }

  @Test(
    "Selected calendar changes age components without changing total days",
    .bug("https://github.com/huahuahu/BirthTracker/issues/43"))
  func selectedCalendarChangesDurationButNotTotalDays() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .autoupdatingCurrent
    let birthDate = try #require(
      calendar.date(from: DateComponents(year: 2024, month: 2, day: 10, hour: 12)))
    let referenceDate = try #require(
      calendar.date(from: DateComponents(year: 2025, month: 1, day: 29, hour: 12)))
    let snapshot = WidgetPersonSnapshot(
      personID: UUID(),
      displayName: "Calendar Test",
      nextBirthdayDate: referenceDate,
      age: 1,
      birthDate: birthDate,
      calendarKind: .gregorian,
      generatedAt: referenceDate,
      sortIndex: 0)

    let gregorianMetrics = try #require(
      ContactAgeSnapshotMetrics.make(
        snapshot: snapshot,
        referenceDate: referenceDate,
        calendarKind: .gregorian))
    let chineseMetrics = try #require(
      ContactAgeSnapshotMetrics.make(
        snapshot: snapshot,
        referenceDate: referenceDate,
        calendarKind: .chinese))

    #expect(
      gregorianMetrics.birthDuration
        == PersonBirthdaySummary.BirthDuration(years: 0, months: 11, days: 19))
    #expect(
      chineseMetrics.birthDuration
        == PersonBirthdaySummary.BirthDuration(years: 1, months: 0, days: 0))
    #expect(gregorianMetrics.totalBirthDays == 354)
    #expect(chineseMetrics.totalBirthDays == gregorianMetrics.totalBirthDays)
  }

  @Test(
    "Alex's total months differ between Gregorian and Islamic calendars",
    .bug("https://github.com/huahuahu/BirthTracker/issues/43"))
  func alexTotalMonthsUseSelectedCalendar() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .autoupdatingCurrent
    let birthDate = try #require(
      calendar.date(from: DateComponents(year: 1990, month: 1, day: 12, hour: 12)))
    let referenceDate = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 8, day: 30, hour: 12)))
    let snapshot = WidgetPersonSnapshot(
      personID: UUID(),
      displayName: "Alex Chen",
      nextBirthdayDate: referenceDate,
      age: 37,
      birthDate: birthDate,
      calendarKind: .gregorian,
      generatedAt: referenceDate,
      sortIndex: 0)

    let gregorianMetrics = try #require(
      ContactAgeSnapshotMetrics.make(
        snapshot: snapshot,
        referenceDate: referenceDate,
        calendarKind: .gregorian))
    let islamicMetrics = try #require(
      ContactAgeSnapshotMetrics.make(
        snapshot: snapshot,
        referenceDate: referenceDate,
        calendarKind: .islamicUmmAlQura))

    #expect(
      gregorianMetrics.birthDuration
        == PersonBirthdaySummary.BirthDuration(years: 36, months: 7, days: 18))
    #expect(
      gregorianMetrics.totalBirthMonthsAndDays
        == ContactAgeSnapshotMetrics.BirthMonthDayDuration(months: 439, days: 18))
    #expect(
      islamicMetrics.birthDuration
        == PersonBirthdaySummary.BirthDuration(years: 37, months: 9, days: 3))
    #expect(
      islamicMetrics.totalBirthMonthsAndDays
        == ContactAgeSnapshotMetrics.BirthMonthDayDuration(months: 453, days: 3))
    #expect(islamicMetrics.totalBirthDays == gregorianMetrics.totalBirthDays)
  }

  @Test(
    "Legacy snapshot cannot reinterpret precomputed age in another calendar",
    .bug("https://github.com/huahuahu/BirthTracker/issues/43"))
  func legacySnapshotDoesNotReinterpretPrecomputedAge() throws {
    let calendar = Calendar(identifier: .gregorian)
    let referenceDate = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 10)))
    let legacySnapshot = WidgetPersonSnapshot(
      personID: UUID(),
      displayName: "Legacy Person",
      nextBirthdayDate: referenceDate,
      age: 2,
      birthDuration: PersonBirthdaySummary.BirthDuration(years: 1, months: 9, days: 26),
      daysUntilNextBirthday: 65,
      totalBirthDays: 665,
      calendarKind: .gregorian,
      schemaVersion: 3,
      generatedAt: referenceDate,
      sortIndex: 0)

    #expect(
      ContactAgeSnapshotMetrics.make(
        snapshot: legacySnapshot,
        referenceDate: referenceDate,
        calendarKind: .chinese) == nil)
  }
}
