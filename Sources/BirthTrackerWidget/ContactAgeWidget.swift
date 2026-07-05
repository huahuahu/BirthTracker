import AppIntents
import Foundation
import Localization
import Models
import Persistence
import SFSafeSymbols
import SwiftUI
import WidgetKit

struct ContactAgeEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetPersonSnapshot?
  let displayFormat: ContactAgeDisplayFormat
  let selectedPersonUnavailable: Bool
}

struct ContactAgeProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> ContactAgeEntry {
    ContactAgeEntry(
      date: .now,
      snapshot: WidgetPersonSnapshot(
        personID: UUID(),
        displayName: "Taylor",
        nextBirthdayDate: .now.addingTimeInterval(86_400),
        age: 3,
        birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 3, days: 4),
        daysUntilNextBirthday: 120,
        totalBirthDays: 825,
        calendarKind: .gregorian,
        generatedAt: .now,
        sortIndex: 0),
      displayFormat: .durationComponents,
      selectedPersonUnavailable: false)
  }

  func snapshot(for configuration: SelectPersonIntent, in context: Context) async -> ContactAgeEntry {
    loadEntry(for: configuration.person?.id)
  }

  func timeline(for configuration: SelectPersonIntent, in context: Context) async -> Timeline<ContactAgeEntry> {
    let entry = loadEntry(for: configuration.person?.id)
    let refreshDate = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now.addingTimeInterval(21_600)
    return Timeline(entries: [entry], policy: .after(refreshDate))
  }

  private func loadEntry(for selectedPersonID: UUID?) -> ContactAgeEntry {
    guard let selectedPersonID else {
      return ContactAgeEntry(
        date: .now,
        snapshot: nil,
        displayFormat: .durationComponents,
        selectedPersonUnavailable: false)
    }

    do {
      guard let snapshot = try WidgetSnapshotStore.fetchPerson(id: selectedPersonID) else {
        return ContactAgeEntry(
          date: .now,
          snapshot: nil,
          displayFormat: .durationComponents,
          selectedPersonUnavailable: true)
      }

      let formatStore = try ContactAgeFormatPreferenceStore.appGroup()
      return ContactAgeEntry(
        date: snapshot.generatedAt,
        snapshot: snapshot,
        displayFormat: formatStore.format(for: selectedPersonID),
        selectedPersonUnavailable: false)
    } catch {
      logger.error("Unable to load contact age entry: \(error.localizedDescription)")
      return ContactAgeEntry(
        date: .now,
        snapshot: nil,
        displayFormat: .durationComponents,
        selectedPersonUnavailable: false)
    }
  }
}

struct ContactAgeWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: BirthTrackerWidgetKind.contactAge,
      intent: SelectPersonIntent.self,
      provider: ContactAgeProvider()
    ) { entry in
      ContactAgeWidgetView(entry: entry)
        .containerBackground(.background, for: .widget)
    }
    .configurationDisplayName(L10n.Widget.contactAge)
    .description(L10n.Widget.contactAgeDescription)
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

private struct ContactAgeWidgetView: View {
  @Environment(\.widgetFamily)
  private var family

  let entry: ContactAgeEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(L10n.Widget.contactAge, systemImage: SFSymbol.clock.rawValue)
        .font(.headline)

      if entry.selectedPersonUnavailable {
        message(L10n.string(L10n.Widget.selectedPersonUnavailable))
      } else if let snapshot = entry.snapshot {
        snapshotContent(snapshot)
      } else {
        message(L10n.string(L10n.Widget.contactAgeChoosePerson))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  @ViewBuilder
  private func snapshotContent(_ snapshot: WidgetPersonSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(snapshot.displayName)
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)

      if snapshot.nextBirthdayDate == nil {
        message(L10n.string(L10n.Widget.noBirthdayRecorded))
      } else if let ageText = ageText(for: snapshot) {
        Button(intent: ToggleContactAgeFormatIntent(personID: snapshot.personID)) {
          VStack(alignment: .leading, spacing: 4) {
            Text(ageText)
              .font(family == .systemSmall ? .title3.bold() : .title.bold())
              .monospacedDigit()
              .lineLimit(2)
              .minimumScaleFactor(0.7)
            Text(formatLabel)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)

        if family == .systemMedium {
          if let days = snapshot.daysUntilNextBirthday {
            Text(L10n.PersonDetail.daysUntilBirthday(days))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Text(L10n.Widget.contactAgeTapToSwitch)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      } else {
        message(L10n.string(L10n.Widget.contactAgeNeedsBirthYear))
      }
    }
  }

  private func ageText(for snapshot: WidgetPersonSnapshot) -> String? {
    switch entry.displayFormat {
    case .durationComponents:
      guard let duration = snapshot.birthDuration else { return nil }
      return L10n.Widget.contactAgeDuration(duration.years, duration.months, duration.days)
    case .totalDays:
      guard let totalBirthDays = snapshot.totalBirthDays else { return nil }
      return L10n.Widget.contactAgeTotalDays(totalBirthDays)
    }
  }

  private var formatLabel: LocalizedStringResource {
    switch entry.displayFormat {
    case .durationComponents:
      L10n.Widget.ageFormatDuration
    case .totalDays:
      L10n.Widget.ageFormatTotalDays
    }
  }

  private func message(_ text: String) -> some View {
    Text(text)
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}

#Preview("duration small", as: .systemSmall) {
  ContactAgeWidget()
} timeline: {
  ContactAgeEntry(
    date: .now,
    snapshot: WidgetPersonSnapshot(
      personID: UUID(),
      displayName: "Taylor",
      nextBirthdayDate: .now.addingTimeInterval(86_400),
      age: 3,
      birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 3, days: 4),
      daysUntilNextBirthday: 120,
      totalBirthDays: 825,
      calendarKind: .gregorian,
      generatedAt: .now,
      sortIndex: 0),
    displayFormat: .durationComponents,
    selectedPersonUnavailable: false)
}

#Preview("days medium", as: .systemMedium) {
  ContactAgeWidget()
} timeline: {
  ContactAgeEntry(
    date: .now,
    snapshot: WidgetPersonSnapshot(
      personID: UUID(),
      displayName: "Taylor",
      nextBirthdayDate: .now.addingTimeInterval(86_400),
      age: 3,
      birthDuration: PersonBirthdaySummary.BirthDuration(years: 2, months: 3, days: 4),
      daysUntilNextBirthday: 120,
      totalBirthDays: 825,
      calendarKind: .gregorian,
      generatedAt: .now,
      sortIndex: 0),
    displayFormat: .totalDays,
    selectedPersonUnavailable: false)
}

#Preview("missing year", as: .systemSmall) {
  ContactAgeWidget()
} timeline: {
  ContactAgeEntry(
    date: .now,
    snapshot: WidgetPersonSnapshot(
      personID: UUID(),
      displayName: "Jordan",
      nextBirthdayDate: .now.addingTimeInterval(86_400),
      age: nil,
      calendarKind: .gregorian,
      generatedAt: .now,
      sortIndex: 0),
    displayFormat: .durationComponents,
    selectedPersonUnavailable: false)
}
