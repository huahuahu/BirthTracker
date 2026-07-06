import Localization
import Persistence
import SwiftUI
import WidgetKit

public struct ContactAgeWidget: Widget {
  public init() {}

  public var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: BirthTrackerWidgetKind.contactAge,
      intent: SelectPersonIntent.self,
      provider: ContactAgeProvider()
    ) { entry in
      ContactAgeWidgetView(entry: entry)
        .containerBackground(.background, for: .widget)
    }
    .configurationDisplayName(L10n.Widget.contactAge)
    .description(L10n.Widget.contactAgeDescription)
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
