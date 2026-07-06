import Localization
import Models
import OSLog
import Persistence
import SFSafeSymbols
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
    loadEntry(for: configuration.selectedPersonID)
  }

  func timeline(for configuration: SelectPersonIntent, in context: Context) async -> Timeline<UpcomingBirthdaysEntry> {
    let entry = loadEntry(for: configuration.selectedPersonID)
    let refreshDate = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now.addingTimeInterval(21_600)
    return Timeline(entries: [entry], policy: .after(refreshDate))
  }

  private func loadEntry(for selectedPersonID: UUID?) -> UpcomingBirthdaysEntry {
    do {
      logger.info("load Entry for \(selectedPersonID?.uuidString ?? "nil")")
      if let selectedPersonID {
        guard let snapshot = try WidgetSnapshotStore.fetchPerson(id: selectedPersonID) else {
          return UpcomingBirthdaysEntry(date: .now, birthdays: [], selectedPersonUnavailable: true)
        }

        return UpcomingBirthdaysEntry(
          date: snapshot.generatedAt,
          birthdays: snapshot.upcomingBirthday.map { [$0] } ?? [],
          selectedPersonUnavailable: false)
      }

      let snapshots = try WidgetSnapshotStore.fetchAll()
      return UpcomingBirthdaysEntry(
        date: snapshots.first?.generatedAt ?? .now,
        birthdays: Array(snapshots.compactMap(\.upcomingBirthday).prefix(8)),
        selectedPersonUnavailable: false)
    } catch {
      logger.error("Unable to load upcoming birthdays entry: \(error.localizedDescription)")
      return UpcomingBirthdaysEntry(date: .now, birthdays: [], selectedPersonUnavailable: false)
    }
  }
}

public struct UpcomingBirthdaysWidget: Widget {
  public init() {}

  public var body: some WidgetConfiguration {
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
  @Environment(\.widgetFamily)
  private var family

  let entry: UpcomingBirthdaysEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(L10n.Widget.title, systemImage: SFSymbol.gift.rawValue)
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
        ForEach(entry.birthdays.prefix(visibleBirthdayLimit)) { birthday in
          VStack(alignment: .leading, spacing: 2) {
            Text(birthday.personName)
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
            Text(birthday.date, format: .dateTime.month(.abbreviated).day())
              .font(.caption)
              .foregroundStyle(.secondary)
            if let duration = birthday.birthDuration {
              Text(L10n.Widget.birthDuration(duration.years, duration.months, duration.days))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var visibleBirthdayLimit: Int {
    family == .systemSmall ? 2 : 3
  }
}

#Preview("small", as: .systemSmall) {
  UpcomingBirthdaysWidget()
} timeline: {
  UpcomingBirthdaysEntry(
    date: .now,
    birthdays: [
      UpcomingBirthday(
        id: UUID(),
        personName: "Taylor",
        date: .now,
        age: 30,
        calendarKind: .gregorian,
        birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 0, days: 0),
        daysUntilNextBirthday: 30),
      UpcomingBirthday(
        id: UUID(),
        personName: "Jordan",
        date: .now.addingTimeInterval(172_800),
        age: 28,
        calendarKind: .gregorian,
        birthDuration: PersonBirthdaySummary.BirthDuration(years: 1, months: 3, days: 4),
        daysUntilNextBirthday: 32),
      UpcomingBirthday(
        id: UUID(),
        personName: "Morgan",
        date: .now.addingTimeInterval(259_200),
        age: 34,
        calendarKind: .gregorian,
        birthDuration: PersonBirthdaySummary.BirthDuration(years: 0, months: 8, days: 12),
        daysUntilNextBirthday: 30),
    ],
    selectedPersonUnavailable: false)
}

#Preview("medium", as: .systemMedium) {
  UpcomingBirthdaysWidget()
} timeline: {
  UpcomingBirthdaysEntry(
    date: .now,
    birthdays: [
      UpcomingBirthday(
        id: UUID(),
        personName: "Taylor",
        date: .now,
        age: 30,
        calendarKind: .gregorian,
        birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 0, days: 0),
        daysUntilNextBirthday: 30)
    ],
    selectedPersonUnavailable: false)
}
//
// #Preview(as: .systemLarge) {
//  UpcomingBirthdaysWidget()
// } timeline: {
//  UpcomingBirthdaysEntry(
//    date: .now,
//    birthdays: [
//      UpcomingBirthday(
//        id: UUID(),
//        personName: "Taylor",
//        date: .now,
//        age: 30,
//        calendarKind: .gregorian,
//        birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 0, days: 0),
//        daysUntilNextBirthday: 30)
//    ],
//    selectedPersonUnavailable: false)
// }
//
//
// #Preview(as: .systemExtraLarge) {
//  UpcomingBirthdaysWidget()
// } timeline: {
//  UpcomingBirthdaysEntry(
//    date: .now,
//    birthdays: [
//      UpcomingBirthday(
//        id: UUID(),
//        personName: "Taylor",
//        date: .now,
//        age: 30,
//        calendarKind: .gregorian,
//        birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 0, days: 0),
//        daysUntilNextBirthday: 30)
//    ],
//    selectedPersonUnavailable: false)
// }
