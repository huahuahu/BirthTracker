import Localization
import Persistence
import SwiftUI
import WidgetKit

public struct UpcomingBirthdaysWidget: Widget {
  public init() {}

  public var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: BirthTrackerWidgetKind.upcomingBirthdays,
      intent: SelectPersonIntent.self,
      provider: UpcomingBirthdaysProvider()
    ) { entry in
      UpcomingBirthdaysWidgetView(entry: entry)
        .containerBackground(.background, for: .widget)
    }
    .configurationDisplayName(L10n.Widget.upcomingBirthdays)
    .description(L10n.Widget.description)
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
