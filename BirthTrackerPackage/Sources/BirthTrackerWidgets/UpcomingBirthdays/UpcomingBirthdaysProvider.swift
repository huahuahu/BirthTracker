import BirthTrackerWidgetIntents
import Foundation
import Logging
import Models
import Persistence
import WidgetKit

struct UpcomingBirthdaysProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> UpcomingBirthdaysEntry {
    UpcomingBirthdaysEntry(
      date: .now,
      birthdays: [
        UpcomingBirthday(
          id: UUID(),
          personName: "Taylor",
          date: .now.addingTimeInterval(86_400),
          age: 30,
          calendarKind: .gregorian)
      ],
      displayCalendar: .followContact,
      selectedPersonUnavailable: false)
  }

  func snapshot(for configuration: SelectUpcomingBirthdaysIntent, in context: Context) async -> UpcomingBirthdaysEntry {
    loadEntry(for: configuration)
  }

  func timeline(for configuration: SelectUpcomingBirthdaysIntent, in context: Context) async -> Timeline<
    UpcomingBirthdaysEntry
  > {
    let entry = loadEntry(for: configuration)
    let refreshDate = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now.addingTimeInterval(21_600)
    return Timeline(entries: [entry], policy: .after(refreshDate))
  }

  private func loadEntry(for configuration: SelectUpcomingBirthdaysIntent) -> UpcomingBirthdaysEntry {
    let selectedPersonID = configuration.selectedPersonID
    do {
      BirthLogger.widget.info(
        "Loading widget entry for \(selectedPersonID?.uuidString ?? "nil").",
        tags: [.data])
      if let selectedPersonID {
        guard let snapshot = try WidgetSnapshotStore.fetchPerson(id: selectedPersonID) else {
          return UpcomingBirthdaysEntry(
            date: .now,
            birthdays: [],
            displayCalendar: configuration.resolvedDisplayCalendar,
            selectedPersonUnavailable: true)
        }

        return UpcomingBirthdaysEntry(
          date: snapshot.generatedAt,
          birthdays: snapshot.upcomingBirthday.map { [$0] } ?? [],
          displayCalendar: configuration.resolvedDisplayCalendar,
          selectedPersonUnavailable: false)
      }

      let snapshots = try WidgetSnapshotStore.fetchAll()
      return UpcomingBirthdaysEntry(
        date: snapshots.first?.generatedAt ?? .now,
        birthdays: Array(snapshots.compactMap(\.upcomingBirthday).prefix(8)),
        displayCalendar: configuration.resolvedDisplayCalendar,
        selectedPersonUnavailable: false)
    } catch {
      BirthLogger.widget.error(
        "Failed to load upcoming birthdays entry: \(error.localizedDescription).",
        tags: [.data, .persistence])
      return UpcomingBirthdaysEntry(
        date: .now,
        birthdays: [],
        displayCalendar: configuration.resolvedDisplayCalendar,
        selectedPersonUnavailable: false)
    }
  }
}
