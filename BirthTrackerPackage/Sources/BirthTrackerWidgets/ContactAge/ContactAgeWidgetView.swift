import BirthTrackerWidgetIntents
import Models
import SFSafeSymbols
import SwiftUI

public struct ContactAgeWidgetView: View {
  @Environment(\.accessibilityReduceMotion)
  private var reduceMotion

  @Environment(\.locale)
  private var locale

  private let date: Date
  private let snapshot: WidgetPersonSnapshot?
  private let displayCalendarKind: BirthdayCalendarKind?
  private let stateID: String?
  private let configuredDisplayFormat: ContactAgeDisplayFormat
  private let displayFormat: ContactAgeDisplayFormat
  private let selectedPersonUnavailable: Bool
  private let durationFormatter = ContactAgeDurationFormatter()

  public init(
    date: Date,
    snapshot: WidgetPersonSnapshot?,
    displayCalendarKind: BirthdayCalendarKind?,
    stateID: String?,
    configuredDisplayFormat: ContactAgeDisplayFormat,
    displayFormat: ContactAgeDisplayFormat,
    selectedPersonUnavailable: Bool
  ) {
    self.date = date
    self.snapshot = snapshot
    self.displayCalendarKind = displayCalendarKind
    self.stateID = stateID
    self.configuredDisplayFormat = configuredDisplayFormat
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
    let ageText = ageText(for: snapshot)
    if snapshot.nextBirthdayDate != nil, let ageText, let stateID {
      Button(
        intent: ToggleContactAgeFormatIntent(
          stateID: stateID,
          configuredFormat: configuredDisplayFormat)
      ) {
        snapshotLayout(snapshot, ageText: ageText)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel(Text(verbatim: snapshot.displayName))
      .accessibilityValue(
        Text(verbatim: "\(ageText), \(WidgetL10n.contactAgeSinceBirth(locale: locale)), \(calendarName(for: snapshot))")
      )
      .accessibilityHint(WidgetL10n.contactAgeTapToSwitch)
      .accessibilityIdentifier("contactAge.toggleFormat")
    } else {
      snapshotLayout(snapshot, ageText: ageText)
    }
  }

  private func snapshotLayout(_ snapshot: WidgetPersonSnapshot, ageText: String?) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Label {
        Text(snapshot.displayName)
      } icon: {
        Image(systemSymbol: .clock)
      }
      .font(.headline)
      .lineLimit(1)

      if snapshot.nextBirthdayDate == nil {
        message(WidgetL10n.string(WidgetL10n.noBirthdayRecorded))
      } else if let ageText {
        ageValue(ageText)

        HStack(alignment: .bottom, spacing: 8) {
          VStack(alignment: .leading, spacing: 2) {
            Text(WidgetL10n.contactAgeSinceBirth(locale: locale))
            Text(calendarName(for: snapshot))
              .accessibilityIdentifier("contactAge.calendar")
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.85)

          Spacer(minLength: 0)

          ContactAgeFormatIndicator(displayFormat: displayFormat)
            .padding(.bottom, 4)
        }
      } else {
        message(WidgetL10n.string(WidgetL10n.contactAgeNeedsBirthYear))
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func ageValue(_ ageText: String) -> some View {
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

  private func ageText(for snapshot: WidgetPersonSnapshot) -> String? {
    guard let birthDate = snapshot.birthDate else { return nil }

    return durationFormatter.string(
      from: birthDate,
      to: date,
      calendarKind: displayCalendarKind ?? snapshot.calendarKind,
      displayFormat: displayFormat,
      locale: locale)
  }

  private func calendarName(for snapshot: WidgetPersonSnapshot) -> String {
    WidgetL10n.calendarName(displayCalendarKind ?? snapshot.calendarKind, locale: locale)
  }

  private func message(_ text: String) -> some View {
    Text(text)
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
  }
}
