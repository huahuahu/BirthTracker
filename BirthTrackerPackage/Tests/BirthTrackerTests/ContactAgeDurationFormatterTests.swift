import Foundation
import Models
import Persistence
import Testing

@testable import BirthTrackerWidgets

@Suite("Contact age duration formatter")
struct ContactAgeDurationFormatterTests {
  private let metrics = ContactAgeSnapshotMetrics(
    birthDuration: .init(years: 38, months: 2, days: 8),
    totalBirthDays: 13_949)

  @Test("System formatter localizes every display granularity")
  func systemFormatterLocalizesEveryDisplayGranularity() {
    let formatter = ContactAgeDurationFormatter()
    let locale = Locale(identifier: "en_US")

    #expect(
      formatter.string(
        for: metrics,
        displayFormat: .yearMonthDay,
        locale: locale) == "38 years, 2 months, 8 days")
    #expect(
      formatter.string(
        for: metrics,
        displayFormat: .monthDay,
        locale: locale) == "458 months, 8 days")
    #expect(
      formatter.string(
        for: metrics,
        displayFormat: .day,
        locale: locale) == "13,949 days")
  }

  @Test("Since birth uses the widget localization catalog")
  func sinceBirthUsesWidgetLocalizationCatalog() {
    #expect(
      WidgetL10n.contactAgeSinceBirth(locale: Locale(identifier: "en")) == "Since birth")
  }
}
