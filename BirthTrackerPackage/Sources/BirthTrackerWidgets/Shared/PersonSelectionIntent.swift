import AppIntents
import Foundation
import Localization
import Persistence

public struct SelectPersonIntent: WidgetConfigurationIntent {
  public static let title: LocalizedStringResource = "Choose Person"
  public static let description = IntentDescription("Choose which person this widget shows.")

  @Parameter(title: "Person", optionsProvider: WidgetPersonOptionsProvider())
  public var personID: String?

  public init() {}

  public init(personID: UUID?) {
    self.personID = personID?.uuidString
  }

  public var selectedPersonID: UUID? {
    guard let personID else { return nil }
    return UUID(uuidString: personID)
  }
}

public struct WidgetPersonOptionsProvider: DynamicOptionsProvider {
  public init() {}

  public func results() async throws -> IntentItemCollection<String> {
    let snapshots = try WidgetSnapshotStore.fetchAll()
    let items = snapshots.map { snapshot in
      IntentItem(snapshot.personID.uuidString, title: "\(snapshot.displayName)")
    }
    logger.info("suggested person IDs \(snapshots.map(\.personID.uuidString))")
    return IntentItemCollection(sections: [IntentItemSection(items: items)])
  }
}
