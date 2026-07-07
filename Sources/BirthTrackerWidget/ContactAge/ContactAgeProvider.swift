import BirthTrackerWidgets
import Foundation
import Logging
import Models
import Persistence
import WidgetKit

struct ContactAgeProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> ContactAgeEntry {
    ContactAgeEntry(
      date: .now,
      snapshot: WidgetPersonSnapshot(
        personID: UUID(),
        displayName: "Taylor",
        nextBirthdayDate: .now.addingTimeInterval(86_400),
        age: 3,
        birthDate: .now.addingTimeInterval(-82_512_000),
        birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 3, days: 4),
        daysUntilNextBirthday: 120,
        totalBirthDays: 825,
        calendarKind: .gregorian,
        generatedAt: .now,
        sortIndex: 0),
      displayFormat: .yearMonthDay,
      selectedPersonUnavailable: false)
  }

  func snapshot(for configuration: SelectPersonIntent, in context: Context) async -> ContactAgeEntry {
    loadEntry(for: configuration.selectedPersonID)
  }

  func timeline(for configuration: SelectPersonIntent, in context: Context) async -> Timeline<ContactAgeEntry> {
    let entryDate = Date.now
    let entry = loadEntry(for: configuration.selectedPersonID, date: entryDate)
    let refreshDate = nextRefreshDate(after: entryDate)
    return Timeline(entries: [entry], policy: .after(refreshDate))
  }

  private func loadEntry(
    for selectedPersonID: UUID?,
    date: Date = .now
  ) -> ContactAgeEntry {
    guard let selectedPersonID else {
      return ContactAgeEntry(
        date: date,
        snapshot: nil,
        displayFormat: .yearMonthDay,
        selectedPersonUnavailable: false)
    }

    do {
      guard let snapshot = try WidgetSnapshotStore.fetchPerson(id: selectedPersonID) else {
        return ContactAgeEntry(
          date: date,
          snapshot: nil,
          displayFormat: .yearMonthDay,
          selectedPersonUnavailable: true)
      }

      let formatStore = try ContactAgeFormatPreferenceStore.appGroup()
      return ContactAgeEntry(
        date: date,
        snapshot: snapshot,
        displayFormat: formatStore.format(for: selectedPersonID),
        selectedPersonUnavailable: false)
    } catch {
      BirthLogger.widget.error(
        "Failed to load contact age entry: \(error.localizedDescription).",
        tags: [.data, .persistence])
      return ContactAgeEntry(
        date: date,
        snapshot: nil,
        displayFormat: .yearMonthDay,
        selectedPersonUnavailable: false)
    }
  }

  private func nextRefreshDate(
    after date: Date,
    calendar: Calendar = .current
  ) -> Date {
    let nextDayStart = calendar.date(
      byAdding: .day,
      value: 1,
      to: calendar.startOfDay(for: date))
    return nextDayStart?.addingTimeInterval(60) ?? date.addingTimeInterval(3_600)
  }
}
