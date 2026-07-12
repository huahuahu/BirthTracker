import Localization
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
    .configurationDisplayName(L10n.Widget.contactAge)
    .description(L10n.Widget.contactAgeDescription)
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
