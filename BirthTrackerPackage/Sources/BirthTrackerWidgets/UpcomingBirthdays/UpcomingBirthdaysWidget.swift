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
    .configurationDisplayName(WidgetL10n.upcomingBirthdays)
    .description(WidgetL10n.description)
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
