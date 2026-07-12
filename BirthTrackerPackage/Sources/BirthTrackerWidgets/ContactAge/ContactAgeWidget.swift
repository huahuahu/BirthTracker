import Persistence
import SwiftUI
import WidgetKit

struct ContactAgeWidget: Widget {
  init() {}

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: BirthTrackerWidgetKind.contactAge,
      intent: SelectPersonIntent.self,
      provider: ContactAgeProvider()
    ) { entry in
      ContactAgeWidgetView(
        date: entry.date,
        snapshot: entry.snapshot,
        displayFormat: entry.displayFormat,
        selectedPersonUnavailable: entry.selectedPersonUnavailable
      )
      .containerBackground(.background, for: .widget)
    }
    .configurationDisplayName(WidgetL10n.contactAge)
    .description(WidgetL10n.contactAgeDescription)
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
