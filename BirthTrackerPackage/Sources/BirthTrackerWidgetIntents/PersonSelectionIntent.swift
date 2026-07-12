import AppIntents
import Foundation
import Logging
import Persistence

public struct SelectPersonIntent: WidgetConfigurationIntent {
  public static let title = LocalizedStringResource("Choose Person", table: "Intents", bundle: .main)
  public static let description = IntentDescription(
    LocalizedStringResource("Choose which person this widget shows.", table: "Intents", bundle: .main))

  @Parameter(
    title: LocalizedStringResource("Contact", table: "Intents", bundle: .main),
    optionsProvider: WidgetPersonOptionsProvider())
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
    BirthLogger.widget.info(
      "Loaded suggested widget person IDs.",
      tags: [.data],
      values: [
        .private(snapshots.map(\.personID.uuidString).joined(separator: ",")),
        .public("result-count=\(items.count)"),
      ])
    return IntentItemCollection(sections: [IntentItemSection(items: items)])
  }
}
