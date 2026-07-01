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
    loadEntry(for: configuration.person?.id)
  }

  func timeline(for configuration: SelectPersonIntent, in context: Context) async -> Timeline<UpcomingBirthdaysEntry> {
    let entry = loadEntry(for: configuration.person?.id)
    let refreshDate = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now.addingTimeInterval(21_600)
    return Timeline(entries: [entry], policy: .after(refreshDate))
  }

  private func loadEntry(for selectedPersonID: UUID?) -> UpcomingBirthdaysEntry {
    let displayDate = Date.now
    do {
      logger.info("load Entry for \(selectedPersonID?.uuidString ?? "nil")")
      if let selectedPersonID {
        guard let snapshot = try WidgetSnapshotStore.fetchPerson(id: selectedPersonID) else {
          return UpcomingBirthdaysEntry(date: displayDate, birthdays: [], selectedPersonUnavailable: true)
        }

        let display = WidgetUpcomingBirthdaysDisplay.make(
          from: [snapshot],
          displayDate: displayDate)
        return UpcomingBirthdaysEntry(
          date: display.referenceDate,
          birthdays: display.birthdays,
          selectedPersonUnavailable: false)
      }

      let snapshots = try WidgetSnapshotStore.fetchAll()
      let display = WidgetUpcomingBirthdaysDisplay.make(
        from: Array(snapshots.prefix(8)),
        displayDate: displayDate)
      return UpcomingBirthdaysEntry(
        date: display.referenceDate,
        birthdays: display.birthdays,
        selectedPersonUnavailable: false)
    } catch {
      return UpcomingBirthdaysEntry(date: displayDate, birthdays: [], selectedPersonUnavailable: false)
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
        .containerBackground(for: .widget) {
          BirthdayWidgetBackground()
        }
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

  private var presentations: [WidgetBirthdayPresentation] {
    entry.birthdays.map {
      WidgetBirthdayPresentation.make(for: $0, referenceDate: entry.date)
    }
  }

  var body: some View {
    Group {
      if entry.selectedPersonUnavailable {
        BirthdayWidgetStatusView(
          title: L10n.Widget.selectedPersonUnavailable,
          message: L10n.Widget.selectedPersonUnavailableDescription)
      } else if let primary = presentations.first {
        switch family {
        case .systemMedium:
          MediumBirthdayWidgetView(
            primary: primary,
            secondary: Array(presentations.dropFirst().prefix(3)))
        default:
          SmallBirthdayWidgetView(primary: primary)
        }
      } else {
        BirthdayWidgetStatusView(
          title: L10n.Widget.noUpcomingBirthdays,
          message: L10n.Widget.emptyDescription)
      }
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

private struct BirthdayWidgetBackground: View {
  var body: some View {
    LinearGradient(
      colors: [
        Color(red: 0.98, green: 0.37, blue: 0.22),
        Color(red: 0.93, green: 0.22, blue: 0.48),
        Color(red: 0.38, green: 0.32, blue: 0.88),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .overlay(alignment: .topTrailing) {
      Circle()
        .fill(.white.opacity(0.18))
        .frame(width: 132, height: 132)
        .offset(x: 42, y: -54)
    }
    .overlay(alignment: .bottomLeading) {
      Circle()
        .fill(.yellow.opacity(0.14))
        .frame(width: 150, height: 150)
        .offset(x: -64, y: 64)
    }
  }
}

private struct SmallBirthdayWidgetView: View {
  let primary: WidgetBirthdayPresentation

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      WidgetHeader()
      Spacer(minLength: 6)
      BirthdayHeroView(presentation: primary, nameFont: .title2.weight(.bold))
    }
    .padding(16)
    .accessibilityElement(children: .combine)
  }
}

private struct MediumBirthdayWidgetView: View {
  let primary: WidgetBirthdayPresentation
  let secondary: [WidgetBirthdayPresentation]

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      VStack(alignment: .leading, spacing: 10) {
        WidgetHeader()
        Spacer(minLength: 4)
        BirthdayHeroView(presentation: primary, nameFont: .title.weight(.bold))
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

      Rectangle()
        .fill(.white.opacity(0.18))
        .frame(width: 1)

      VStack(alignment: .leading, spacing: 10) {
        Text(L10n.Widget.upcomingBirthdays)
          .font(.caption.weight(.bold))
          .foregroundStyle(.white.opacity(0.8))
          .textCase(.uppercase)

        if secondary.isEmpty {
          Text(L10n.Widget.moreBirthdaysPlaceholder)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.72))
            .lineLimit(3)
            .frame(maxHeight: .infinity, alignment: .center)
        } else {
          ForEach(secondary) { presentation in
            UpcomingBirthdayRow(presentation: presentation)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .padding(16)
  }
}

private struct WidgetHeader: View {
  var body: some View {
    Label {
      Text(verbatim: "BirthTracker")
    } icon: {
      Image(systemSymbol: .gift)
    }
    .font(.caption.weight(.bold))
    .foregroundStyle(.white.opacity(0.84))
    .labelStyle(.titleAndIcon)
  }
}

private struct BirthdayHeroView: View {
  let presentation: WidgetBirthdayPresentation
  let nameFont: Font

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(L10n.Widget.nextBirthday)
        .font(.caption2.weight(.bold))
        .foregroundStyle(.white.opacity(0.76))
        .textCase(.uppercase)

      CountdownBadge(text: presentation.countdownText)

      Text(verbatim: presentation.birthday.personName)
        .font(nameFont)
        .foregroundStyle(.white)
        .lineLimit(2)
        .minimumScaleFactor(0.72)

      BirthdayMetadataView(presentation: presentation)
    }
  }
}

private struct CountdownBadge: View {
  let text: String

  var body: some View {
    Text(verbatim: text)
      .font(.headline.weight(.heavy))
      .foregroundStyle(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(.white.opacity(0.2), in: Capsule())
      .overlay {
        Capsule()
          .stroke(.white.opacity(0.24), lineWidth: 1)
      }
  }
}

private struct BirthdayMetadataView: View {
  let presentation: WidgetBirthdayPresentation

  var body: some View {
    HStack(spacing: 6) {
      Text(presentation.birthday.date, format: .dateTime.month(.abbreviated).day())

      if let ageText = presentation.ageText {
        Text(verbatim: ageText)
      }
    }
    .font(.caption.weight(.semibold))
    .foregroundStyle(.white.opacity(0.78))
    .lineLimit(1)
    .minimumScaleFactor(0.82)
  }
}

private struct UpcomingBirthdayRow: View {
  let presentation: WidgetBirthdayPresentation

  var body: some View {
    HStack(alignment: .center, spacing: 9) {
      VStack(spacing: 1) {
        Text(presentation.birthday.date, format: .dateTime.month(.abbreviated))
          .font(.caption2.weight(.heavy))
        Text(presentation.birthday.date, format: .dateTime.day())
          .font(.caption.weight(.heavy))
      }
      .foregroundStyle(.white)
      .frame(width: 42, height: 42)
      .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

      VStack(alignment: .leading, spacing: 2) {
        Text(verbatim: presentation.birthday.personName)
          .font(.subheadline.weight(.bold))
          .lineLimit(1)
          .minimumScaleFactor(0.8)

        Text(verbatim: presentation.countdownText)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.white.opacity(0.72))
          .lineLimit(1)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

private struct BirthdayWidgetStatusView: View {
  let title: LocalizedStringResource
  let message: LocalizedStringResource

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      WidgetHeader()
      Spacer(minLength: 4)
      Image(systemSymbol: .sparkles)
        .font(.title.weight(.bold))
        .foregroundStyle(.white.opacity(0.9))
        .accessibilityHidden(true)

      Text(title)
        .font(.headline.weight(.bold))
        .lineLimit(2)

      Text(message)
        .font(.caption)
        .foregroundStyle(.white.opacity(0.74))
        .lineLimit(3)
    }
    .padding(16)
    .accessibilityElement(children: .combine)
  }
}

extension WidgetBirthdayPresentation {
  fileprivate var countdownText: String {
    switch daysUntil {
    case 0:
      L10n.string(L10n.Widget.countdownToday)
    case 1:
      L10n.string(L10n.Widget.countdownTomorrow)
    default:
      L10n.Widget.countdownDays(daysUntil)
    }
  }

  fileprivate var ageText: String? {
    birthday.age.map(L10n.Widget.turningAge)
  }
}

private enum UpcomingBirthdaysWidgetPreviewData {
  static let referenceDate = Date(timeIntervalSince1970: 1_783_036_800)

  static let birthdays = [
    UpcomingBirthday(
      id: UUID(),
      personName: "Taylor",
      date: referenceDate.addingTimeInterval(86_400),
      age: 30,
      calendarKind: .gregorian),
    UpcomingBirthday(
      id: UUID(),
      personName: "Morgan",
      date: referenceDate.addingTimeInterval(691_200),
      age: 28,
      calendarKind: .gregorian),
    UpcomingBirthday(
      id: UUID(),
      personName: "Alex",
      date: referenceDate.addingTimeInterval(2_678_400),
      age: nil,
      calendarKind: .gregorian),
  ]
}

#Preview("small", as: .systemSmall) {
  UpcomingBirthdaysWidget()
} timeline: {
  UpcomingBirthdaysEntry(
    date: UpcomingBirthdaysWidgetPreviewData.referenceDate,
    birthdays: Array(UpcomingBirthdaysWidgetPreviewData.birthdays.prefix(1)),
    selectedPersonUnavailable: false)
}

#Preview("medium", as: .systemMedium) {
  UpcomingBirthdaysWidget()
} timeline: {
  UpcomingBirthdaysEntry(
    date: UpcomingBirthdaysWidgetPreviewData.referenceDate,
    birthdays: UpcomingBirthdaysWidgetPreviewData.birthdays,
    selectedPersonUnavailable: false)
}

#Preview("empty", as: .systemSmall) {
  UpcomingBirthdaysWidget()
} timeline: {
  UpcomingBirthdaysEntry(
    date: UpcomingBirthdaysWidgetPreviewData.referenceDate,
    birthdays: [],
    selectedPersonUnavailable: false)
}

#Preview("unavailable", as: .systemSmall) {
  UpcomingBirthdaysWidget()
} timeline: {
  UpcomingBirthdaysEntry(
    date: UpcomingBirthdaysWidgetPreviewData.referenceDate,
    birthdays: [],
    selectedPersonUnavailable: true)
}
