import Localization
import SFSafeSymbols
import SwiftUI
import WidgetKit

struct UpcomingBirthdaysWidgetView: View {
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
