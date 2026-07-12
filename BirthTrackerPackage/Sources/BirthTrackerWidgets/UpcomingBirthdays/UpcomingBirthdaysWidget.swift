import Localization
import Persistence
import SwiftUI
import WidgetKit

struct UpcomingBirthdaysWidget: Widget {
  init() {}

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: BirthTrackerWidgetKind.upcomingBirthdays,
      intent: SelectPersonIntent.self,
      provider: UpcomingBirthdaysProvider()
    ) { entry in
      UpcomingBirthdaysWidgetView(
        birthdays: entry.birthdays,
        selectedPersonUnavailable: entry.selectedPersonUnavailable
      )
      .containerBackground(.background, for: .widget)
    }
    .configurationDisplayName(L10n.Widget.upcomingBirthdays)
    .description(L10n.Widget.description)
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
