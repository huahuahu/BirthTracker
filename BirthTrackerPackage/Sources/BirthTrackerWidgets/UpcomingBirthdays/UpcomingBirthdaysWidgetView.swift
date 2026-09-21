import BirthTrackerWidgetIntents
import Models
import SFSafeSymbols
import SwiftUI
import WidgetKit

public struct UpcomingBirthdaysWidgetView: View {
  @Environment(\.widgetFamily)
  private var family

  @Environment(\.locale)
  private var locale

  private let birthdays: [UpcomingBirthday]
  private let displayCalendar: WidgetDisplayCalendar
  private let selectedPersonUnavailable: Bool

  public init(
    birthdays: [UpcomingBirthday],
    displayCalendar: WidgetDisplayCalendar,
    selectedPersonUnavailable: Bool
  ) {
    self.birthdays = birthdays
    self.displayCalendar = displayCalendar
    self.selectedPersonUnavailable = selectedPersonUnavailable
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(WidgetL10n.title, systemImage: SFSymbol.gift.rawValue)
        .font(.headline)

      if selectedPersonUnavailable {
        Text(WidgetL10n.selectedPersonUnavailable)
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if birthdays.isEmpty {
        Text(WidgetL10n.noUpcomingBirthdays)
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        ForEach(birthdays.prefix(visibleBirthdayLimit)) { birthday in
          VStack(alignment: .leading, spacing: 2) {
            Text(birthday.personName)
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
            Text(
              UpcomingBirthdayDateFormatter.string(
                for: birthday.date,
                calendarKind: displayCalendar.resolve(following: birthday.calendarKind),
                locale: locale)
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            if let duration = birthday.birthDuration {
              Text(WidgetL10n.birthDuration(duration.years, duration.months, duration.days))
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
