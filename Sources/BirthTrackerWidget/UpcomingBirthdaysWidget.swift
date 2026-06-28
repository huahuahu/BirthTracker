import Localization
import Models
import Persistence
import SwiftUI
import WidgetKit

struct UpcomingBirthdaysEntry: TimelineEntry {
  let date: Date
  let birthdays: [UpcomingBirthday]
  let selectedPersonUnavailable: Bool
}

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
      selectedPersonUnavailable: false)
  }

  func snapshot(for configuration: SelectPersonIntent, in context: Context) async -> UpcomingBirthdaysEntry {
    loadEntry(for: configuration.person?.id)
  }

  func timeline(for configuration: SelectPersonIntent, in context: Context) async -> Timeline<UpcomingBirthdaysEntry> {
    let entry = loadEntry(for: configuration.person?.id)
    let refreshDate = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now.addingTimeInterval(21_600)
    return Timeline(entries: [entry], policy: .after(refreshDate))
  }

  private func loadEntry(for selectedPersonID: UUID?) -> UpcomingBirthdaysEntry {
    do {
      if let selectedPersonID {
        guard let snapshot = try WidgetSnapshotStore.fetchPerson(id: selectedPersonID) else {
          return UpcomingBirthdaysEntry(date: .now, birthdays: [], selectedPersonUnavailable: true)
        }

        return UpcomingBirthdaysEntry(
          date: snapshot.generatedAt,
          birthdays: [snapshot.upcomingBirthday],
          selectedPersonUnavailable: false)
      }

      let snapshots = try WidgetSnapshotStore.fetchAll()
      return UpcomingBirthdaysEntry(
        date: snapshots.first?.generatedAt ?? .now,
        birthdays: snapshots.prefix(8).map(\.upcomingBirthday),
        selectedPersonUnavailable: false)
    } catch {
      return UpcomingBirthdaysEntry(date: .now, birthdays: [], selectedPersonUnavailable: false)
    }
  }
}

struct UpcomingBirthdaysWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: BirthTrackerWidgetKind.upcomingBirthdays,
      intent: SelectPersonIntent.self,
      provider: UpcomingBirthdaysProvider()
    ) { entry in
      UpcomingBirthdaysWidgetView(entry: entry)
        .containerBackground(.background, for: .widget)
    }
    .configurationDisplayName(L10n.Widget.upcomingBirthdays)
    .description(L10n.Widget.description)
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

private struct UpcomingBirthdaysWidgetView: View {
  let entry: UpcomingBirthdaysEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(L10n.Widget.title, systemImage: "gift")
        .font(.headline)

      if entry.selectedPersonUnavailable {
        Text(L10n.Widget.selectedPersonUnavailable)
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if entry.birthdays.isEmpty {
        Text(L10n.Widget.noUpcomingBirthdays)
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        ForEach(entry.birthdays.prefix(3)) { birthday in
          VStack(alignment: .leading, spacing: 2) {
            Text(birthday.personName)
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
            Text(birthday.date, format: .dateTime.month(.abbreviated).day())
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

#Preview(as: .systemSmall) {
  UpcomingBirthdaysWidget()
} timeline: {
  UpcomingBirthdaysEntry(
    date: .now,
    birthdays: [
      UpcomingBirthday(id: UUID(), personName: "Taylor", date: .now, age: 30, calendarKind: .gregorian)
    ],
    selectedPersonUnavailable: false)
}
