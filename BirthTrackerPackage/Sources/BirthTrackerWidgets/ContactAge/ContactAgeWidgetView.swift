import Localization
import Models
import Persistence
import SFSafeSymbols
import SwiftUI
import WidgetKit

public struct ContactAgeWidgetView: View {
  @Environment(\.widgetFamily)
  private var family

  private let date: Date
  private let snapshot: WidgetPersonSnapshot?
  private let displayFormat: ContactAgeDisplayFormat
  private let selectedPersonUnavailable: Bool
  private let durationFormatter = ContactAgeDurationFormatter()

  public init(
    date: Date,
    snapshot: WidgetPersonSnapshot?,
    displayFormat: ContactAgeDisplayFormat,
    selectedPersonUnavailable: Bool
  ) {
    self.date = date
    self.snapshot = snapshot
    self.displayFormat = displayFormat
    self.selectedPersonUnavailable = selectedPersonUnavailable
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(L10n.Widget.contactAge, systemImage: SFSymbol.clock.rawValue)
        .font(.headline)

      if selectedPersonUnavailable {
        message(L10n.string(L10n.Widget.selectedPersonUnavailable))
      } else if let snapshot {
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
    guard let metrics = contactAgeMetrics(for: snapshot) else { return nil }

    return durationFormatter.string(
      for: metrics,
      displayFormat: displayFormat)
  }

  private func contactAgeMetrics(for snapshot: WidgetPersonSnapshot) -> ContactAgeSnapshotMetrics? {
    ContactAgeSnapshotMetrics.make(
      snapshot: snapshot,
      referenceDate: date)
  }

  private var formatLabel: LocalizedStringResource {
    switch displayFormat {
    case .yearMonthDay:
      L10n.Widget.ageFormatYearMonthDay
    case .monthDay:
      L10n.Widget.ageFormatMonthDay
    case .day:
      L10n.Widget.ageFormatDay
    }
  }

  private func message(_ text: String) -> some View {
    Text(text)
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}
