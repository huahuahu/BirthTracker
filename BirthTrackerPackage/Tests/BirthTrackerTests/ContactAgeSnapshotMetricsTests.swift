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
}
