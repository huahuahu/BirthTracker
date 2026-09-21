import BirthTrackerWidgetIntents
import Persistence
import SwiftUI
import WidgetKit

struct UpcomingBirthdaysWidget: Widget {
  let kind: String = BirthTrackerWidgetKind.upcomingBirthdays

  init() {}

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: SelectUpcomingBirthdaysIntent.self,
      provider: UpcomingBirthdaysProvider()
    ) { entry in
      UpcomingBirthdaysWidgetView(
        birthdays: entry.birthdays,
        displayCalendar: entry.displayCalendar,
        selectedPersonUnavailable: entry.selectedPersonUnavailable
      )
      .containerBackground(.background, for: .widget)
    }
    .configurationDisplayName(WidgetL10n.upcomingBirthdays)
    .description(WidgetL10n.description)
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
