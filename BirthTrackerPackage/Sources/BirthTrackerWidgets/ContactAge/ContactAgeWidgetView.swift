import Localization
import Models
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
      } else if
        let metrics = contactAgeMetrics(for: snapshot),
        let ageText = ageText(for: metrics)
      {
        let resolvedDisplayFormat = displayFormat.resolved(in: metrics.availableDisplayFormats)
        let canToggleFormat = metrics.availableDisplayFormats.count > 1

        if canToggleFormat {
          Button(intent: ToggleContactAgeFormatIntent(personID: snapshot.personID)) {
            ageContent(ageText: ageText, displayFormat: resolvedDisplayFormat)
          }
          .buttonStyle(.plain)
        } else {
          ageContent(ageText: ageText, displayFormat: resolvedDisplayFormat)
        }

        if family == .systemMedium {
          if let days = snapshot.daysUntilNextBirthday {
            Text(L10n.PersonDetail.daysUntilBirthday(days))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          if canToggleFormat {
            Text(L10n.Widget.contactAgeTapToSwitch)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      } else {
        message(L10n.string(L10n.Widget.contactAgeNeedsBirthYear))
      }
    }
  }

  private func ageContent(
    ageText: String,
    displayFormat: ContactAgeDisplayFormat
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(ageText)
        .font(family == .systemSmall ? .title3.bold() : .title.bold())
        .monospacedDigit()
        .lineLimit(2)
        .minimumScaleFactor(0.7)
      Text(formatLabel(for: displayFormat))
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func ageText(for metrics: ContactAgeSnapshotMetrics) -> String? {
    let resolvedDisplayFormat = displayFormat.resolved(in: metrics.availableDisplayFormats)

    return durationFormatter.string(
      for: metrics,
      displayFormat: resolvedDisplayFormat)
  }

  private func contactAgeMetrics(for snapshot: WidgetPersonSnapshot) -> ContactAgeSnapshotMetrics? {
    ContactAgeSnapshotMetrics.make(
      snapshot: snapshot,
      referenceDate: date)
  }

  private func formatLabel(for displayFormat: ContactAgeDisplayFormat) -> LocalizedStringResource {
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
