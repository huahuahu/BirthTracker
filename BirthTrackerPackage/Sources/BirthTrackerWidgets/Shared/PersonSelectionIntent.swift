import AppIntents
import Foundation
import Localization
import Persistence

struct SelectPersonIntent: WidgetConfigurationIntent {
  static let title: LocalizedStringResource = "Choose Person"
  static let description = IntentDescription("Choose which person this widget shows.")

  @Parameter(title: "Person", optionsProvider: WidgetPersonOptionsProvider())
  var personID: String?

  init() {}

  init(personID: UUID?) {
    self.personID = personID?.uuidString
  }

  var selectedPersonID: UUID? {
    guard let personID else { return nil }
    return UUID(uuidString: personID)
  }
}

struct WidgetPersonOptionsProvider: DynamicOptionsProvider {
  func results() async throws -> IntentItemCollection<String> {
    let snapshots = try WidgetSnapshotStore.fetchAll()
    let items = snapshots.map { snapshot in
      IntentItem(snapshot.personID.uuidString, title: "\(snapshot.displayName)")
    }
    logger.info("suggested person IDs \(snapshots.map(\.personID.uuidString))")
    return IntentItemCollection(sections: [IntentItemSection(items: items)])
  }
}
