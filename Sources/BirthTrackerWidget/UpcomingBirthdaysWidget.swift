import Localization
import Models
import Persistence
import SFSafeSymbols
import SwiftUI
import WidgetKit

struct UpcomingBirthdaysEntry: TimelineEntry {
  let date: Date
  let birthdays: [UpcomingBirthday]
}

struct UpcomingBirthdaysProvider: TimelineProvider {
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
      ])
  }

  func getSnapshot(in context: Context, completion: @escaping (UpcomingBirthdaysEntry) -> Void) {
    completion(loadEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<UpcomingBirthdaysEntry>) -> Void) {
    let entry = loadEntry()
    let refreshDate = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now.addingTimeInterval(21_600)
    completion(Timeline(entries: [entry], policy: .after(refreshDate)))
  }

  private func loadEntry() -> UpcomingBirthdaysEntry {
    guard let url = AppGroup.snapshotURL,
      let data = try? Data(contentsOf: url),
      let snapshot = try? JSONDecoder.birthTracker.decode(WidgetSnapshot.self, from: data)
    else {
      return UpcomingBirthdaysEntry(date: .now, birthdays: [])
    }

    return UpcomingBirthdaysEntry(date: snapshot.generatedAt, birthdays: snapshot.birthdays)
  }
}

struct UpcomingBirthdaysWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: BirthTrackerWidgetKind.upcomingBirthdays,
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
      Label(L10n.Widget.title, systemImage: SFSymbol.gift.rawValue)
        .font(.headline)

      if entry.birthdays.isEmpty {
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
    ])
}
