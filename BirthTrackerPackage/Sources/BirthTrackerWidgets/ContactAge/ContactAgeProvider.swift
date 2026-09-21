import BirthTrackerWidgetIntents
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
      displayCalendarKind: .gregorian,
      stateID: nil,
      configuredDisplayFormat: .yearMonthDay,
      displayFormat: .yearMonthDay,
      selectedPersonUnavailable: false)
  }

  func snapshot(for configuration: SelectPersonIntent, in context: Context) async -> ContactAgeEntry {
    loadEntry(for: configuration)
  }

  func timeline(for configuration: SelectPersonIntent, in context: Context) async -> Timeline<ContactAgeEntry> {
    let entryDate = Date.now
    let entry = loadEntry(for: configuration, date: entryDate)
    let refreshDate = nextRefreshDate(after: entryDate)
    return Timeline(entries: [entry], policy: .after(refreshDate))
  }

  private func loadEntry(
    for configuration: SelectPersonIntent,
    date: Date = .now
  ) -> ContactAgeEntry {
    let selectedPersonID = configuration.selectedPersonID
    let configuredDisplayFormat = configuration.resolvedAgeDisplayFormat
    let stateID = configuration.contactAgeStateID
    guard let selectedPersonID else {
      return ContactAgeEntry(
        date: date,
        snapshot: nil,
        displayCalendarKind: nil,
        stateID: nil,
        configuredDisplayFormat: configuredDisplayFormat,
        displayFormat: configuredDisplayFormat,
        selectedPersonUnavailable: false)
    }

    do {
      guard let snapshot = try WidgetSnapshotStore.fetchPerson(id: selectedPersonID) else {
        return ContactAgeEntry(
          date: date,
          snapshot: nil,
          displayCalendarKind: nil,
          stateID: stateID,
          configuredDisplayFormat: configuredDisplayFormat,
          displayFormat: configuredDisplayFormat,
          selectedPersonUnavailable: true)
      }

      let displayFormat =
        try stateID.map {
          try ContactAgeFormatPreferenceStore.appGroup().format(
            for: $0,
            configuredFormat: configuredDisplayFormat)
        } ?? configuredDisplayFormat
      BirthLogger.widget.info(
        "Loaded contact age format.",
        tags: [.persistence],
        values: [
          .private(stateID ?? "none"),
          .public("configured-format=\(configuredDisplayFormat.rawValue)"),
          .public("selected-format=\(displayFormat.rawValue)"),
        ])
      return ContactAgeEntry(
        date: date,
        snapshot: snapshot,
        displayCalendarKind: configuration.resolvedDisplayCalendar.resolve(following: snapshot.calendarKind),
        stateID: stateID,
        configuredDisplayFormat: configuredDisplayFormat,
        displayFormat: displayFormat,
        selectedPersonUnavailable: false)
    } catch {
      BirthLogger.widget.error(
        "Failed to load contact age entry: \(error.localizedDescription).",
        tags: [.data, .persistence])
      return ContactAgeEntry(
        date: date,
        snapshot: nil,
        displayCalendarKind: nil,
        stateID: stateID,
        configuredDisplayFormat: configuredDisplayFormat,
        displayFormat: configuredDisplayFormat,
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
