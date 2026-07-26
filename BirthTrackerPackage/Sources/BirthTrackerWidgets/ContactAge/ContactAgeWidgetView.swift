import BirthTrackerWidgetIntents
import Models
import Persistence
import SFSafeSymbols
import SwiftUI

public struct ContactAgeWidgetView: View {
  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion

  @Environment(\.locale)
  private var locale

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
    Group {
      if selectedPersonUnavailable {
        message(WidgetL10n.string(WidgetL10n.selectedPersonUnavailable))
      } else if let snapshot {
        snapshotContent(snapshot)
      } else {
        message(WidgetL10n.string(WidgetL10n.contactAgeChoosePerson))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  @ViewBuilder
  private func snapshotContent(_ snapshot: WidgetPersonSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label {
        Text(snapshot.displayName)
      } icon: {
        Image(systemSymbol: .clock)
      }
      .font(.headline)
      .lineLimit(1)

      if snapshot.nextBirthdayDate == nil {
        message(WidgetL10n.string(WidgetL10n.noBirthdayRecorded))
      } else if let ageText = ageText(for: snapshot) {
        Button(intent: ToggleContactAgeFormatIntent(personID: snapshot.personID)) {
          ZStack(alignment: .leading) {
            Text(ageText)
              .font(.title3.bold())
              .monospacedDigit()
              .lineLimit(2)
              .minimumScaleFactor(0.7)
              .id(displayFormat.rawValue)
              .transition(reduceMotion ? .opacity : .push(from: .bottom))
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
          .compositingGroup()
          .clipped()
          .animation(reduceMotion ? nil : .smooth, value: displayFormat.rawValue)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ageText)
        .accessibilityHint(WidgetL10n.contactAgeTapToSwitch)

        HStack {
          Text(WidgetL10n.contactAgeSinceBirth(locale: locale))
            .font(.caption)
            .foregroundStyle(.secondary)

          Spacer()

          ContactAgeFormatIndicator(displayFormat: displayFormat)
        }
      } else {
        message(WidgetL10n.string(WidgetL10n.contactAgeNeedsBirthYear))
      }
    }
  }

  private func ageText(for snapshot: WidgetPersonSnapshot) -> String? {
    guard let metrics = contactAgeMetrics(for: snapshot) else { return nil }

    return durationFormatter.string(
      for: metrics,
      displayFormat: displayFormat,
      locale: locale)
  }

  private func contactAgeMetrics(for snapshot: WidgetPersonSnapshot) -> ContactAgeSnapshotMetrics? {
    ContactAgeSnapshotMetrics.make(
      snapshot: snapshot,
      referenceDate: date)
  }

  private func message(_ text: String) -> some View {
    Text(text)
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}
